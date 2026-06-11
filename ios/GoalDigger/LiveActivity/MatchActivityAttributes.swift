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
/// CDN.
struct MatchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var homeScore: Int
        var awayScore: Int
        /// Compact status for the badge: "KO", "12'", "HT", "67'", "FT".
        var statusLabel: String
        /// Optional one-liner (e.g. the live-brief headline at half-time).
        var note: String?
    }

    /// Fixed for the life of the match.
    var fixtureId: Int
    var homeName: String   // short name, e.g. "Mexico"
    var awayName: String   // short name, e.g. "S. Africa"
    var homeFlag: String   // emoji, e.g. "🇲🇽"
    var awayFlag: String   // emoji, e.g. "🇿🇦"
    var groupLabel: String?  // e.g. "Group A"
}
