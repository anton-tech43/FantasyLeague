import Foundation

/// One-row-per-team snapshot of where his team sits in the season today.
/// Populated by the gd-season-state cloud routine (runs daily at 01:00 UTC).
/// Used to render the Season Primer screen shown ONCE after onboarding —
/// see `SeasonPrimerView`.
struct TeamSeasonState: Codable, Equatable {
    /// Which phase of the football calendar we're in. The primer headline
    /// adapts to this — pre-season teaser vs run-in stakes vs off-season
    /// dust-settling all read differently.
    enum Phase: String, Codable {
        case preSeason = "pre_season"
        case midSeason = "mid_season"
        case runIn = "run_in"
        case offSeason = "off_season"
        case postSeason = "post_season"
    }

    struct NextFixture: Codable, Equatable {
        let opponent: String
        let kickoffTime: Date
        /// "Home" or "Away" — capitalised per the routine schema.
        let venue: String

        enum CodingKeys: String, CodingKey {
            case opponent
            case kickoffTime = "kickoff_time"
            case venue
        }
    }

    let teamId: String
    let phase: Phase
    /// Two sentences. Plain English. Where the team is right now.
    let summary: String
    /// One notable line about this week or last week.
    let keyFact: String
    /// Exactly 3 short text-message-style openers she can send him today.
    let welcomeLines: [String]
    /// Optional — omitted in pre-season / off-season when no concrete next match exists.
    let nextFixture: NextFixture?

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case phase, summary
        case keyFact = "key_fact"
        case welcomeLines = "welcome_lines"
        case nextFixture = "next_fixture"
    }
}
