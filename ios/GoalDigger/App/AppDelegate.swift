import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Global rose cursor tint on all text fields and text views
        let roseTint = UIColor(red: 232/255, green: 57/255, blue: 125/255, alpha: 1)
        UITextField.appearance().tintColor = roseTint
        UITextView.appearance().tintColor = roseTint

        // Deep mauve overscroll background (prevents white flash on rubber-band)
        UIScrollView.appearance().backgroundColor = UIColor(red: 45/255, green: 27/255, blue: 46/255, alpha: 1)

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationService.shared.handleTokenRegistration(token)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("⚠️ APNs registration failed: \(error)")
        #endif
    }

    // Notification tapped
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let contentId = userInfo["content_id"] as? String,
           let uuid = UUID(uuidString: contentId) {
            // Route to correct feed context before navigation
            if userInfo["everyone_talking"] as? Bool == true {
                AppState.shared.activeContext = .everyoneTalking
            }
            AppState.shared.deepLinkContentId = uuid
        }
        completionHandler()
    }

    // Notification received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
