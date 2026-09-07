import Foundation
import UIKit

/// Fire-and-forget client error reporter.
///
/// Posts to the `client-error-alert` Supabase edge function, which logs to
/// the `client_errors` table and pushes a notification to any APNs token
/// registered in `dev_alert_devices`.
///
/// **Never blocks the calling code.** Reports are dispatched on a background
/// task; failures are silently swallowed so a broken reporter never breaks
/// the user's experience. The whole point is to surface errors quickly to
/// the developer without changing the app's behaviour for users.
enum ErrorReporter {

    /// Categories of failures we report. Keep these stable — the backend
    /// uses `error_type` for throttling and dashboards.
    enum ErrorType: String {
        case fetchFeed = "fetch_feed"
        case fetchEveryoneFeed = "fetch_everyone_feed"
        case fetchItem = "fetch_item"
        case fetchTeamPage = "fetch_team_page"
        case fetchPlayerCards = "fetch_player_cards"
        case decode = "decode"
        case emptyFeed = "empty_feed"
    }

    /// Report a thrown error from a fetch call.
    static func report(_ type: ErrorType, error: Error, requestPath: String? = nil, teamId: String? = nil) {
        let message: String
        if let api = error as? APIError {
            message = api.errorDescription ?? "\(api)"
        } else {
            message = String(describing: error)
        }
        send(type: type, message: message, requestPath: requestPath, teamId: teamId)
    }

    /// Report a non-error condition — e.g. an empty feed when content was expected.
    static func reportInfo(_ type: ErrorType, message: String, requestPath: String? = nil, teamId: String? = nil) {
        send(type: type, message: message, requestPath: requestPath, teamId: teamId)
    }

    // MARK: - Private

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }()

    private static func send(type: ErrorType, message: String, requestPath: String?, teamId: String?) {
        guard let url = makeURL() else { return }

        var payload: [String: Any] = [
            "error_type": type.rawValue,
            "message": message,
            "app_version": appVersion,
            "device_model": deviceModel,
            "os_version": osVersion,
        ]
        if let requestPath { payload["request_path"] = requestPath }
        if let teamId { payload["team_id"] = teamId }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        // Detached task — fire and forget. Errors silently swallowed.
        Task.detached(priority: .background) {
            _ = try? await session.data(for: request)
        }
    }

    private static func makeURL() -> URL? {
        guard let host = Bundle.main.infoDictionary?["SUPABASE_HOST"] as? String,
              !host.isEmpty,
              !host.contains("YOUR_PROJECT") else { return nil }
        return URL(string: "https://\(host)/functions/v1/client-error-alert")
    }

    private static let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.contains("YOUR_ANON_KEY") else { return "" }
        return key
    }()

    private static let appVersion: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }()

    private static let deviceModel: String = {
        var sysinfo = utsname()
        uname(&sysinfo)
        let raw = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        return raw.isEmpty ? UIDevice.current.model : raw
    }()

    private static let osVersion: String = {
        UIDevice.current.systemVersion
    }()
}
