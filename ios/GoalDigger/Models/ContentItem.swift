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
    let boldPrediction: String

    enum CodingKeys: String, CodingKey {
        case ifTheyWin = "if_they_win"
        case ifTheyLose = "if_they_lose"
        case boldPrediction = "bold_prediction"
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

struct TeamPageContent: Codable {
    let nickname: String?
    let stadium: String?
    let manager: String?
    let topPlayers: [TopPlayer]?
    let biggestRival: String?
    let funFact: String?
    let seasonSummary: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case stadium
        case manager
        case topPlayers = "top_players"
        case biggestRival = "biggest_rival"
        case funFact = "fun_fact"
        case seasonSummary = "season_summary"
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

struct TeamPage: Codable {
    let teamId: String?
    let content: TeamPageContent

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case content
    }
}
