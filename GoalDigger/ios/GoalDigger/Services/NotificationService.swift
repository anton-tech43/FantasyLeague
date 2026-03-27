import Foundation
import UserNotifications

/// Push notification registration and handling.
/// Full implementation in task I9.
class NotificationService {
    static let shared = NotificationService()

    /// Request notification permissions from the user
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
            print("[GoalDigger] Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    /// Register device token with the backend
    func registerToken(_ token: String) async {
        guard let teamId = AppState.shared.selectedTeam?.rawValue else { return }
        do {
            try await APIClient.shared.registerToken(token, teamId: teamId)
        } catch {
            print("[GoalDigger] Token registration failed: \(error.localizedDescription)")
        }
    }
}

import UIKit
