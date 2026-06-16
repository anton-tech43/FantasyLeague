import Foundation
import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            return false
        }
    }

    func handleTokenRegistration(_ token: String) {
        // iOS reissues the same APNs token across cold starts unless the app
        // is reinstalled or the user resets their device. Re-POSTing on every
        // launch is wasted bandwidth and creates log noise. Compare against
        // the stored value first; only re-POST when the token changed OR
        // when a previous POST failed (apnsTokenRegistered flag is unset).
        let previous = UserDefaults.standard.string(forKey: "apnsToken")
        let alreadyRegistered = UserDefaults.standard.bool(forKey: "apnsTokenRegistered")
        let unchanged = previous == token
        UserDefaults.standard.set(token, forKey: "apnsToken")

        // V2.0: either a team OR a country is sufficient. The flow can produce:
        //   - team only (V1.x users who haven't done WC migration)
        //   - country only (V2.0 WC-only audience)
        //   - both (V2.0 fans of both)
        let teamId = AppState.shared.selectedTeam?.rawValue
        let countryId = AppState.shared.selectedCountry?.rawValue
        guard teamId != nil || countryId != nil else { return }

        // During onboarding, OnboardingFlow.completeOnboarding() owns the
        // canonical registerToken POST — it has the final tier/team/country
        // in hand. APNs can deliver the token any time between the prompt
        // grant and the flow's end, so a naive auto-register here would
        // POST with default tier=2 and create a stale row. The token is
        // still persisted above so completeOnboarding can pick it up.
        // Re-issues AFTER onboarding flow through normally.
        guard AppState.shared.hasCompletedOnboarding else { return }
        let tier = AppState.shared.selectedTier

        // Re-register when the APNs token changed OR the followed scope
        // (country | team | tier) changed since the last successful POST.
        // Without the scope check, switching the followed country never updated
        // the backend device_tokens.country_id (the token value is unchanged),
        // so pushes kept targeting the old country until a reinstall.
        let scope = "\(countryId ?? "")|\(teamId ?? "")|\(tier)"
        let lastScope = UserDefaults.standard.string(forKey: "lastRegisteredScope")
        if unchanged && alreadyRegistered && scope == lastScope { return }
        Task {
            do {
                try await APIClient.shared.registerToken(
                    token,
                    teamId: teamId,
                    countryId: countryId,
                    tier: tier
                )
                await MainActor.run {
                    UserDefaults.standard.set(true, forKey: "apnsTokenRegistered")
                    UserDefaults.standard.set(scope, forKey: "lastRegisteredScope")
                }
            } catch {
                // Leave apnsTokenRegistered false; next launch or token-changed
                // event will retry. Avoid a silent permanent black hole.
                #if DEBUG
                print("⚠️ registerToken failed: \(error)")
                #endif
            }
        }
    }

    /// Re-register the stored APNs token after the followed country/team changes
    /// (e.g. the Settings country picker), so device_tokens.country_id updates
    /// immediately instead of waiting for the next launch. No-op if no token yet.
    func reregisterForFollowChange() {
        guard let token = UserDefaults.standard.string(forKey: "apnsToken"), !token.isEmpty else { return }
        handleTokenRegistration(token)
    }

    func checkNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
