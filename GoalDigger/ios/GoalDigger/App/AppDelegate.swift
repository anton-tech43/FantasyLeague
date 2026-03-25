import UIKit
import UserNotifications

/// Handles APNs registration and push notification interactions.
/// See AGENT_CONTRACTS.md Contract 2 for the notification payload format.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - APNs Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationService.shared.handleTokenRegistration(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
    }

    // MARK: - Notification Tap (Deep Link)

    /// Contract 2: Parse `content_id` from APNs payload and set deep link.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let contentId = userInfo["content_id"] as? String,
           let uuid = UUID(uuidString: contentId) {
            AppState.shared.deepLinkContentId = uuid
        }
        completionHandler()
    }

    // MARK: - Foreground Notification

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
