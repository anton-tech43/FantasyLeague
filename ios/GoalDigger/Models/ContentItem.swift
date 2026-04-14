import Foundation

struct ContentItem: Identifiable, Codable {
    let id: UUID
    let teamId: String
    let type: ContentType
    let headline: String
    let body: String
    let kickoffTime: Date?
    let emotionalContext: String?
    let publishedAt: Date

    // Raw talking points — decoded differently based on type
    private let talkingPointsRaw: TalkingPointsPayload

    // Everyone's talking about — cross-team feed
    let everyoneTalking: Bool
    let everyoneTalkingHeadline: String?
    let everyoneTalkingBody: String?
    let everyoneTalkingTalkingPoints: [String]?
    let worthKnowing: Bool

    // Immersive card fields
    let immersiveHeadline: String?
    let immersiveContext: String?
    let immersiveContextFallback: String?

    // Analogy review state
    let analogyReviewed: Bool
    let analogyApproved: Bool
    let analogyAutoPublished: Bool

    enum ContentType: String, Codable {
        case news
        case matchday
    }

    enum CodingKeys: String, CodingKey {
        case id
        case teamId = "team_id"
        case type
        case headline
        case body
        case talkingPointsRaw = "talking_points"
        case kickoffTime = "kickoff_time"
        case emotionalContext = "emotional_context"
        case publishedAt = "published_at"

        // Everyone's talking about
        case everyoneTalking = "everyone_talking"
        case everyoneTalkingHeadline = "everyone_talking_headline"
        case everyoneTalkingBody = "everyone_talking_body"
        case everyoneTalkingTalkingPoints = "everyone_talking_talking_points"
        case worthKnowing = "worth_knowing"

        // Immersive card
        case immersiveHeadline = "immersive_headline"
        case immersiveContext = "immersive_context"
        case immersiveContextFallback = "immersive_context_fallback"

        // Analogy review
        case analogyReviewed = "analogy_reviewed"
        case analogyApproved = "analogy_approved"
        case analogyAutoPublished = "analogy_auto_published"
    }

    // Custom decoder for backward compatibility with cached items missing new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        teamId = try container.decode(String.self, forKey: .teamId)
        type = try container.decode(ContentType.self, forKey: .type)
        headline = try container.decode(String.self, forKey: .headline)
        body = try container.decode(String.self, forKey: .body)
        talkingPointsRaw = try container.decode(TalkingPointsPayload.self, forKey: .talkingPointsRaw)
        kickoffTime = try container.decodeIfPresent(Date.self, forKey: .kickoffTime)
        emotionalContext = try container.decodeIfPresent(String.self, forKey: .emotionalContext)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)

        // New fields — all default to false/nil for backward compatibility
        everyoneTalking = (try? container.decodeIfPresent(Bool.self, forKey: .everyoneTalking)) ?? false
        everyoneTalkingHeadline = try? container.decodeIfPresent(String.self, forKey: .everyoneTalkingHeadline)
        everyoneTalkingBody = try? container.decodeIfPresent(String.self, forKey: .everyoneTalkingBody)
        everyoneTalkingTalkingPoints = try? container.decodeIfPresent([String].self, forKey: .everyoneTalkingTalkingPoints)
        worthKnowing = (try? container.decodeIfPresent(Bool.self, forKey: .worthKnowing)) ?? false
        immersiveHeadline = try? container.decodeIfPresent(String.self, forKey: .immersiveHeadline)
        immersiveContext = try? container.decodeIfPresent(String.self, forKey: .immersiveContext)
        immersiveContextFallback = try? container.decodeIfPresent(String.self, forKey: .immersiveContextFallback)
        analogyReviewed = (try? container.decodeIfPresent(Bool.self, forKey: .analogyReviewed)) ?? false
        analogyApproved = (try? container.decodeIfPresent(Bool.self, forKey: .analogyApproved)) ?? false
        analogyAutoPublished = (try? container.decodeIfPresent(Bool.self, forKey: .analogyAutoPublished)) ?? false
    }

    /// The context/analogy line to display on the immersive card.
    /// Shows the approved analogy if reviewed, otherwise the safe fallback.
    var displayContext: String? {
        if analogyApproved { return immersiveContext }
        return immersiveContextFallback
    }

    var regularTalkingPoints: [String] {
        switch talkingPointsRaw {
        case .simple(let points):
            return points
        case .matchday(let data):
            return data.regular
        }
    }

    var postMatchCheatSheet: PostMatchCheatSheet? {
        guard case .matchday(let data) = talkingPointsRaw else { return nil }
        return data.postMatch
    }

    var matchdayMetadata: MatchdayMetadata? {
        guard case .matchday(let data) = talkingPointsRaw else { return nil }
        return data.metadata
    }
}

// MARK: - Matchday Talking Points Types

struct MatchdayTalkingPoints: Codable {
    let regular: [String]
    let postMatch: PostMatchCheatSheet
    let metadata: MatchdayMetadata

    enum CodingKeys: String, CodingKey {
        case regular
        case postMatch = "post_match"
        case metadata
    }
}

struct PostMatchCheatSheet: Codable {
    let ifTheyWin: String
    let ifTheyLose: String

    enum CodingKeys: String, CodingKey {
        case ifTheyWin = "if_they_win"
        case ifTheyLose = "if_they_lose"
    }
}

struct MatchdayMetadata: Codable {
    let preMatchMood: String
    let rivalryLevel: String

    enum CodingKeys: String, CodingKey {
        case preMatchMood = "pre_match_mood"
        case rivalryLevel = "rivalry_level"
    }
}

// MARK: - Dual-format talking_points decoder

enum TalkingPointsPayload: Codable {
    case simple([String])
    case matchday(MatchdayTalkingPoints)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try decoding as matchday structured object first
        if let matchdayData = try? container.decode(MatchdayTalkingPoints.self) {
            self = .matchday(matchdayData)
            return
        }
        // Fall back to simple string array
        if let simpleArray = try? container.decode([String].self) {
            self = .simple(simpleArray)
            return
        }
        self = .simple([])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .simple(let array):
            try container.encode(array)
        case .matchday(let data):
            try container.encode(data)
        }
    }
}

// MARK: - Player Card & Team Page models

struct PlayerCard: Identifiable, Codable {
    var id: String { playerName }
    let teamId: String?
    let playerName: String
    let position: String
    let age: Int?
    let summary: String
    let vibe: String?
    let form: String?

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case playerName = "player_name"
        case position
        case age
        case summary
        case vibe
        case form
    }
}

// MARK: - Team Page — Versioned JSONB schema (matches Supabase team_pages.content)

struct TeamPageContent: Codable {
    let schemaVersion: Int
    let cards: TeamPageCards

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case cards
    }
}

struct TeamPageCards: Codable {
    let basics: BasicsCard?
    let manager: ManagerCard?
    let onesToKnow: OnesToKnowCard?
    let rivalry: RivalryCard?
    let form: FormCard?
    let season: SeasonCard?
    let nextFixture: NextFixtureCard?

    enum CodingKeys: String, CodingKey {
        case basics
        case manager
        case onesToKnow = "ones_to_know"
        case rivalry
        case form
        case season
        case nextFixture = "next_fixture"
    }
}

struct BasicsCard: Codable {
    let updatedAt: String?
    let nickname: String
    let stadium: String
    let funFact: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case nickname
        case stadium
        case funFact = "fun_fact"
    }
}

struct ManagerCard: Codable {
    let updatedAt: String?
    let name: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case name
        case summary
    }
}

struct OnesToKnowCard: Codable {
    let updatedAt: String?
    let players: [TopPlayer]

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case players
    }
}

struct TopPlayer: Codable, Identifiable {
    var id: String { name }
    let name: String
    let position: String
    let oneLiner: String?

    enum CodingKeys: String, CodingKey {
        case name
        case position
        case oneLiner = "one_liner"
    }
}

struct RivalryCard: Codable {
    let updatedAt: String?
    let text: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case text
    }
}

struct FormCard: Codable {
    let updatedAt: String?
    let leaguePosition: Int
    let leaguePositionLabel: String
    let recentForm: String
    let formSummary: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case leaguePosition = "league_position"
        case leaguePositionLabel = "league_position_label"
        case recentForm = "recent_form"
        case formSummary = "form_summary"
    }
}

struct SeasonCard: Codable {
    let updatedAt: String?
    let summary: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case summary
    }
}

struct NextFixtureCard: Codable {
    let updatedAt: String?
    let opponent: String
    let date: String
    let venue: String
    let preview: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case opponent
        case date
        case venue
        case preview
    }
}

struct TeamPage: Codable {
    let teamId: String?
    let content: TeamPageContent

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case content
    }
}

// MARK: - Team Page Cache

struct CachedTeamPage: Codable {
    let content: TeamPageContent
    let cachedAt: Date

    var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > 24 * 60 * 60
    }
}

enum TeamPageCache {
    private static func key(for teamId: String) -> String {
        "teamPage_\(teamId)"
    }

    static func load(teamId: String) -> CachedTeamPage? {
        guard let data = UserDefaults.standard.data(forKey: key(for: teamId)) else { return nil }
        return try? JSONDecoder().decode(CachedTeamPage.self, from: data)
    }

    static func save(content: TeamPageContent, teamId: String) {
        let cached = CachedTeamPage(content: content, cachedAt: Date())
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: key(for: teamId))
        }
    }

    static func clear(teamId: String) {
        UserDefaults.standard.removeObject(forKey: key(for: teamId))
    }
}
