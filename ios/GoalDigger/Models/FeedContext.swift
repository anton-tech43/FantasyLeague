import Foundation

/// Which feed context is active — a specific club, a country, or the
/// cross-team "Everyone's Talking About" feed.
///
/// There used to be a fourth case, `.worldChampionship`: a tournament-wide
/// feed shown alongside the followed entities. It was gated on a hardcoded
/// date, 22 July 2026, three days after the final. From that morning on,
/// nothing offered it, nothing could set it, and every arm that handled it
/// was unreachable — about 290 lines across five files.
///
/// It was kept as a deliberate off switch for the next tournament, and the
/// argument for keeping it was that flipping the date brings it back. That is
/// true of the client and not of anything behind it: all 48 country rows and
/// the `world_championship` entity are `is_active = false`, `poll_leagues()`
/// no longer returns league 1, and `best-third.ts` says in its own header
/// that its maths is for "the 2026 World Cup, where the 8 best of the 12
/// third-placed teams advance". Euro 2028 is 24 teams and six groups. The
/// shell would wake up pointed at a tournament that is over.
///
/// So it goes, 2026-09-23. Git has it, and the part actually worth keeping —
/// the group and best-third maths, with its tests — is untouched in
/// `_shared/`, where a future tournament can use it.
enum FeedContext: Equatable, Hashable {
    case team(Team)
    case country(Country)
    case everyoneTalking

    /// The tournament's entity id on the backend. Still live and NOT part of
    /// the feed context: LiveActivityManager asks for "whichever tournament
    /// match is on right now" independently of any feed (`:105`).
    static let worldChampionshipEntityId = "world_championship"

    var displayName: String {
        switch self {
        case .team(let team):     return team.shortName
        case .country(let country): return country.shortName
        case .everyoneTalking:    return "Football"
        }
    }

    /// Key used for UserDefaults storage (e.g. unread tracker timestamps)
    var storageKey: String {
        switch self {
        case .team(let team):       return "context_team_\(team.rawValue)"
        case .country(let country): return "context_country_\(country.rawValue)"
        case .everyoneTalking:      return "context_everyone"
        }
    }

    /// SF Symbol name for the context pill icon
    var iconName: String {
        switch self {
        case .team, .country:  return "" // Uses crest image instead
        case .everyoneTalking: return "soccerball"
        }
    }

    /// Full display name for dropdown rows
    var dropdownLabel: String {
        switch self {
        case .team(let team):       return team.shortName
        case .country(let country): return country.shortName
        case .everyoneTalking:      return "Everyone's talking about"
        }
    }
}
