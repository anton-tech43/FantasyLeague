import Foundation

/// Current live-match state for the user's followed country, returned by the
/// `live-match-current` Edge Function (sourced from `match_status_state`).
/// Used by the foreground-start fallback when push-to-start hasn't run.
struct LiveMatchSnapshot: Codable {
    let fixtureId: Int
    let homeTeamId: String   // slug, e.g. "mexico"
    let awayTeamId: String   // slug, e.g. "south_africa"
    let homeGoals: Int
    let awayGoals: Int
    let status: String       // API-Football short: "NS","1H","HT","2H","ET","FT",…
    let elapsed: Int?        // minute
    let groupLabel: String?

    enum CodingKeys: String, CodingKey {
        case fixtureId = "fixture_id"
        case homeTeamId = "home_team_id"
        case awayTeamId = "away_team_id"
        case homeGoals = "home_goals"
        case awayGoals = "away_goals"
        case status
        case elapsed
        case groupLabel = "group_label"
    }

    /// Live = the match is being played (so an activity should run). FT and
    /// pre-kickoff are excluded — the activity ends / hasn't started.
    var isLive: Bool { ["1H", "HT", "2H", "ET", "BT", "P", "LIVE"].contains(status) }

    /// Period-based badge label, matching the backend's wcStatusLabel (the
    /// foreground-started activity is then updated by period-based pushes, so
    /// the label stays consistent across both paths).
    var statusLabel: String {
        switch status {
        case "NS":               return "KO"
        case "1H":               return "1st half"
        case "HT":               return "HT"
        case "2H":               return "2nd half"
        case "ET", "BT":         return "Extra time"
        case "P":                return "Penalties"
        case "FT", "AET", "PEN": return "FT"
        default:                 return status
        }
    }

    var contentState: MatchActivityAttributes.ContentState {
        .init(homeScore: homeGoals, awayScore: awayGoals, statusLabel: statusLabel, note: nil)
    }
}
