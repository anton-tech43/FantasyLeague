import Foundation

/// Represents which feed context is active — either a specific team
/// (PL club), a country (WC national team), or the cross-team
/// "Everyone's Talking About" feed.
enum FeedContext: Equatable, Hashable {
    case team(Team)
    case country(Country)
    case everyoneTalking

    var displayName: String {
        switch self {
        case .team(let team):
            return team.shortName
        case .country(let country):
            return country.shortName
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
        case .everyoneTalking:
            return "context_everyone"
        }
    }

    /// SF Symbol name for the context pill icon
    var iconName: String {
        switch self {
        case .team, .country:
            return "" // Uses crest image instead
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
        case .everyoneTalking:
            return "Everyone's talking about"
        }
    }
}
