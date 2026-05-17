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
        if unchanged && alreadyRegistered { return }

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

    func checkNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
