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
        UserDefaults.standard.set(token, forKey: "apnsToken")
        guard let team = AppState.shared.selectedTeam else { return }
        let tier = AppState.shared.selectedTier
        Task {
            try? await APIClient.shared.registerToken(token, teamId: team.rawValue, tier: tier)
        }
    }

    func checkNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
