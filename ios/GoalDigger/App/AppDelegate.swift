import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // V2.0: image cache for AsyncImage. The CountrySelectionView (48
        // flags) and Meet team/manager views (player + manager headshots)
        // all hit api-sports.io CDN — without a shared cache each appearance
        // triggers a fresh network fetch, thrashing on scroll. 20 MB memory
        // + 100 MB disk covers all crests/flags/headshots with room to spare
        // (each PNG is ~5-50 KB).
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "image_cache"
        )

        // Global rose cursor tint on all text fields and text views
        let roseTint = UIColor(red: 232/255, green: 57/255, blue: 125/255, alpha: 1)
        UITextField.appearance().tintColor = roseTint
        UITextView.appearance().tintColor = roseTint

        // TEST A: temporarily disabled — UIScrollView.appearance() applies to
        // every scroll view in the app, including the one UITextField uses
        // internally to scroll long text. That's why typing a long word turned
        // the input field's background dark mauve.
        // Deep mauve overscroll background (prevents white flash on rubber-band)
        // UIScrollView.appearance().backgroundColor = UIColor(red: 45/255, green: 27/255, blue: 46/255, alpha: 1)

        // Verify custom fonts are registered correctly
        #if DEBUG
        for family in UIFont.familyNames.sorted() where family.contains("Jakarta") || family.contains("League") {
            print("Font family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
        #endif

        // Retry token registration if a previous attempt failed silently.
        // Scenario: user completed onboarding while offline / Supabase was
        // having a moment → registerToken POST threw → apnsTokenRegistered
        // never set. Without this, the token-equality guard in
        // NotificationService.handleTokenRegistration would prevent ANY
        // future POST. Re-asking iOS to deliver the token redrives the
        // whole pipeline (delivery → handleTokenRegistration → retry POST).
        let hasStoredToken = UserDefaults.standard.string(forKey: "apnsToken") != nil
        let alreadyRegistered = UserDefaults.standard.bool(forKey: "apnsTokenRegistered")
        if hasStoredToken && !alreadyRegistered {
            Task { @MainActor in
                let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                if status == .authorized || status == .provisional {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        // Observe Live Activity tokens (push-to-start + per-activity update
        // tokens) so the backend can start/update live WC match activities on
        // the Lock Screen + Dynamic Island. Idempotent; safe at every launch.
        LiveActivityManager.shared.start()

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Real iOS devices emit a 32-byte (64 hex char) APNs token. iOS 17+
        // simulators can emit a longer "extended" format (80 bytes / 160 hex
        // chars) intended for simulator-only push testing. Backend validators
        // — both the `register-dev-device` Edge Function regex and the
        // `valid_apns_token` DB CHECK constraint — reject anything that isn't
        // exactly 64 hex chars. Truncating here keeps sim flow valid for
        // local smoke tests; on a real device the prefix is a no-op since
        // the raw string is already 64 chars.
        let raw = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let token = String(raw.prefix(64))
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
