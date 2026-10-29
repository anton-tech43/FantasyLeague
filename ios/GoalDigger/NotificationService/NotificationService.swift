import Foundation
import UserNotifications

/// Runs on every alert push iOS shows, app closed or not, and logs
/// `push_delivered` (migration 144). It is the only trace a user who reads
/// her pushes on the Lock Screen and never opens the app leaves, and iOS
/// skips it when her notifications are off. The push is shown unchanged.
final class NotificationService: UNNotificationServiceExtension {
    private let lock = NSLock()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        content = request.content
        guard let delivery = Self.deliveryRequest(request.content.userInfo) else { return finish() }
        // ponytail: one attempt, no queue. A push just arrived, so she is
        // online; a lost delivery undercounts by one. Queue in the App Group
        // if the digest ever shows deliveries well below sends.
        URLSession.shared.dataTask(with: delivery) { _, _, _ in self.finish() }.resume()
    }

    override func serviceExtensionTimeWillExpire() { finish() }

    /// Shows the push exactly once, whichever of the request or the clock wins.
    private func finish() {
        lock.lock()
        let handler = contentHandler
        contentHandler = nil
        lock.unlock()
        if let handler, let content { handler(content) }
    }

    /// Nil until the app has run once since this build (no install id yet)
    /// or when the build has no backend configured.
    static func deliveryRequest(_ userInfo: [AnyHashable: Any]) -> URLRequest? {
        let shared = SharedAnalytics.defaults
        guard let installId = shared?.string(forKey: SharedAnalytics.installIdKey),
              let host = Bundle.main.infoDictionary?["SUPABASE_HOST"] as? String, !host.isEmpty,
              let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty,
              let url = URL(string: "https://\(host)/rest/v1/rpc/log_events") else { return nil }
        var props = shared?.dictionary(forKey: SharedAnalytics.commonPropsKey) ?? [:]
        props["kind"] = SharedAnalytics.pushKind(userInfo["content_id"] as? String)
        let body: [String: Any] = [
            "p_install_id": installId,
            "p_events": [[
                "name": "push_delivered",
                "at": ISO8601DateFormatter().string(from: Date()),
                "props": props,
            ]],
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
}
