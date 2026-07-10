import Foundation

/// Represents which feed context is active — either a specific team
/// (PL club), a country (WC national team), the tournament-wide
/// World Championship feed, or the cross-team "Everyone's Talking
/// About" feed.
enum FeedContext: Equatable, Hashable {
    case team(Team)
    case country(Country)
    case worldChampionship
    case everyoneTalking

    /// The content_items / Edge Function entity id for the tournament-wide
    /// feed. Lives here so the string exists in exactly one place.
    static let worldChampionshipEntityId = "world_championship"

    var displayName: String {
        switch self {
        case .team(let team):
            return team.shortName
        case .country(let country):
            return country.shortName
        case .worldChampionship:
            return "World Championship"
        case .everyoneTalking:
            return "Football"
        }
    }

    /// Key used for UserDefaults storage (e.g. unread tracker timestamps)
    var storageKey: String {
        switch self {
        case .team(let team):
            return "context_team_\(team.rawValue)"
        case .country(let country):
            return "context_country_\(country.rawValue)"
        case .worldChampionship:
            return "context_wc"
        case .everyoneTalking:
            return "context_everyone"
        }
    }

    /// SF Symbol name for the context pill icon
    var iconName: String {
        switch self {
        case .team, .country:
            return "" // Uses crest image instead
        case .worldChampionship:
            return "trophy"
        case .everyoneTalking:
            return "soccerball"
        }
    }

    /// Full display name for dropdown rows
    var dropdownLabel: String {
        switch self {
        case .team(let team):
            return team.shortName
        case .country(let country):
            return country.shortName
        case .worldChampionship:
            return "World Championship"
        case .everyoneTalking:
            return "Everyone's talking about"
        }
    }
}

/// Season gate for the tournament feed context. Hardcoded end date:
/// the World Championship row self-hides after the final (2026-07-19)
/// plus a few days of post-final content.
enum WCSeason {
    private static let hideAfter = ISO8601DateFormatter().date(from: "2026-07-22T00:00:00Z")!
    static var isVisible: Bool { Date() < hideAfter }
}
