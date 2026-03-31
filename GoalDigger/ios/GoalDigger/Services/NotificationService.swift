import Foundation
import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()

    /// Request notification permission and register for remote notifications
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await registerForRemoteNotifications()
            }
            return granted
        } catch {
            print("[Notifications] Permission request failed: \(error)")
            return false
        }
    }

    /// Register with APNs
    @MainActor
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Handle successful token registration — send to backend
    func handleTokenRegistration(_ token: String) {
        guard let team = AppState.shared.selectedTeam else { return }

        // Store token locally for team change updates
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")

        Task {
            do {
                try await APIClient.shared.registerToken(token, teamId: team.rawValue)
                print("[Notifications] Token registered with backend for \(team.rawValue)")
            } catch {
                print("[Notifications] Failed to register token: \(error)")
            }
        }
    }

    /// Update the backend when the user changes team
    func handleTeamChange(newTeam: Team) {
        guard let token = UserDefaults.standard.string(forKey: "apnsDeviceToken") else { return }

        Task {
            do {
                try await APIClient.shared.updateTeam(token: token, newTeamId: newTeam.rawValue)
                print("[Notifications] Team updated to \(newTeam.rawValue)")
            } catch {
                print("[Notifications] Failed to update team: \(error)")
            }
        }
    }

    /// Check current notification authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
