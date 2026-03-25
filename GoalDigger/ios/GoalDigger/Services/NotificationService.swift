import UserNotifications
import UIKit

/// Manages push notification permissions and token registration.
actor NotificationService {
    static let shared = NotificationService()

    // MARK: - Request Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Check Status

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Token Registration

    func handleTokenRegistration(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apnsToken")

        guard let team = AppState.shared.selectedTeam else { return }

        Task {
            try? await APIClient.shared.registerToken(token, teamId: team.rawValue)
        }
    }
}
