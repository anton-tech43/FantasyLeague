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

    // MARK: One-beat redesign (the canonical fields the new primer reads)
    /// 2-5 word personalised headline ("Arsenal are flying", "Spurs are slipping").
    let stateLine: String?
    /// 1-2 sentences (≤220 chars) on how HE will feel/act this week. Sister-voice.
    let feelingLine: String?

    // MARK: Legacy fields (deprecated for this surface, kept optional for
    // backward compatibility with rows generated before the redesign).
    /// Two sentences. Plain English. Where the team is right now. DEPRECATED.
    let summary: String?
    /// One notable line about this week or last week. DEPRECATED.
    let keyFact: String?
    /// Exactly 3 short text-message-style openers she can send him today. DEPRECATED.
    let welcomeLines: [String]?

    /// Optional — omitted in pre-season / off-season when no concrete next match exists.
    /// Kept for back-compat with older rows generated before the array field
    /// was added. Prefer `nextFixtures` when populated; fall back to this.
    let nextFixture: NextFixture?

    /// Up to 10 upcoming fixtures. Added in the onboarding V1.2 redesign so
    /// the CalendarOptInView step can sync a meaningful slate of matches in
    /// one tap. Optional during the rollout window — fall back to
    /// `nextFixture` when nil/empty.
    let nextFixtures: [NextFixture]?

    /// Canonical accessor: returns the array if present, else wraps the
    /// singular `nextFixture` in a one-item array, else empty.
    /// Callers should use this rather than reading the raw fields directly.
    var fixturesForSync: [NextFixture] {
        if let nextFixtures, !nextFixtures.isEmpty { return nextFixtures }
        if let nextFixture { return [nextFixture] }
        return []
    }

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case phase
        case stateLine = "state_line"
        case feelingLine = "feeling_line"
        case summary
        case keyFact = "key_fact"
        case welcomeLines = "welcome_lines"
        case nextFixture = "next_fixture"
        case nextFixtures = "next_fixtures"
    }
}
