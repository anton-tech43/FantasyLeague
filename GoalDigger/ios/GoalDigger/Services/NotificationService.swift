import Foundation
import UserNotifications

// TODO: Implement in I9 — Push notification handling
class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("[Notifications] Permission request failed: \(error)")
            return false
        }
    }

    func registerForRemoteNotifications() {
        // TODO: Implement
    }
}
