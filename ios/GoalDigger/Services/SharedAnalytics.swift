import Foundation

/// What the app and its Notification Service Extension both need to log
/// usage under one install id. Compiled into both targets; the extension
/// cannot see the app's own UserDefaults, only this App Group's.
enum SharedAnalytics {
    static let suite = "group.com.goaldigger.app"
    static let installIdKey = "analyticsInstallId"
    /// The common props of the app's last event (tier, club, version, env),
    /// so a delivery logged while the app is closed splits the same way.
    static let commonPropsKey = "analyticsCommonProps"

    static var defaults: UserDefaults? { UserDefaults(suiteName: suite) }

    /// `push_opened` / `push_delivered` kind from a push's content_id:
    /// `live-goal-123` → goal, `myturn-prep-…` → prep, `matchday-…` →
    /// matchday, an article UUID → article. Checked in AppDelegate.
    static func pushKind(_ contentId: String?) -> String {
        guard let contentId else { return "none" }
        if UUID(uuidString: contentId) != nil { return "article" }
        let parts = contentId.split(whereSeparator: { $0 == "-" || $0 == ":" })
        if parts.first == "live" || parts.first == "myturn", parts.count > 1 { return String(parts[1]) }
        return parts.first.map(String.init) ?? "none"
    }
}
