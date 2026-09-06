import Foundation
import ActivityKit

/// Shared between the GoalDigger app and the GoalDiggerLiveActivity widget
/// extension (this file is a compile member of BOTH targets).
///
/// Every piece of display data travels inside the activity payload — the fixed
/// `attributes` for the match, and the `ContentState` that the backend pushes
/// on each score/status change. So the widget process needs no network and no
/// shared container: it renders exactly what it is handed. Flags are emoji
/// (Country.flagEmoji) because the widget can't reliably load the remote crest
/// CDN; PL clubs carry an empty flag and the widget shows the name alone.
struct MatchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var homeScore: Int
        var awayScore: Int
        /// Period status for the badge: "1st half", "HT", "2nd half", "FT", etc.
        var statusLabel: String
        /// Live match minute (API-Football elapsed). Sent only during an active
        /// half; nil at HT / break / full-time. Backed by match_status_state.
        var elapsed: Int?
        /// Optional one-liner (e.g. the live-brief headline at half-time).
        var note: String?

        /// Badge text: the live minute as "63' / 90" during a half (so she sees
        /// the game runs 90 minutes), otherwise the period label. Minutes past
        /// 90 (extra time) drop the "/ 90".
        var badgeText: String {
            if let m = elapsed, m > 0 {
                return m <= 90 ? "\(m)' / 90" : "\(m)'"
            }
            return statusLabel
        }
    }

    /// Fixed for the life of the match.
    var fixtureId: Int
    var homeName: String   // short name, e.g. "Mexico"
    var awayName: String   // short name, e.g. "S. Africa"
    var homeFlag: String   // emoji, e.g. "🇲🇽"
    var awayFlag: String   // emoji, e.g. "🇿🇦"
    var groupLabel: String?  // e.g. "Group A"
}
