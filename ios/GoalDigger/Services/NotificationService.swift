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

        // V2.2: a device may follow up to 2 clubs + 2 countries (all equal).
        // At least one entity is sufficient to register.
        let teamIds = AppState.shared.selectedTeams.map(\.rawValue)
        let countryIds = AppState.shared.selectedCountries.map(\.rawValue)
        guard !teamIds.isEmpty || !countryIds.isEmpty else { return }

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
        // (countries | teams | tier) changed since the last successful POST.
        // Without the scope check, changing a follow never updated the backend
        // (the token value is unchanged), so pushes kept targeting the old set
        // until a reinstall. Sorted so order-only changes don't force a re-POST.
        let scope = "\(countryIds.sorted().joined(separator: ","))" +
            "|\(teamIds.sorted().joined(separator: ","))|\(tier)"
        let lastScope = UserDefaults.standard.string(forKey: "lastRegisteredScope")
        if unchanged && alreadyRegistered && scope == lastScope { return }
        Task {
            do {
                try await APIClient.shared.registerToken(
                    token,
                    teamIds: teamIds,
                    countryIds: countryIds,
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

    /// ONB-3: if onboarding finished but no APNs token is stored yet (delivery
    /// can lag the permission grant by seconds), re-ask iOS to vend it so the
    /// device registers THIS session instead of going push-silent until the next
    /// launch. When the token lands, AppDelegate -> handleTokenRegistration POSTs
    /// it (the hasCompletedOnboarding guard now passes). No-op if a token exists
    /// or notifications aren't authorized.
    func redriveTokenIfNeeded() {
        let hasToken = !(UserDefaults.standard.string(forKey: "apnsToken") ?? "").isEmpty
        guard !hasToken else { return }
        Task {
            let status = await checkNotificationStatus()
            guard status == .authorized || status == .provisional else { return }
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func checkNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
