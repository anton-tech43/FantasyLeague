import Foundation

/// A single content item from the Goal Digger backend.
/// Represents either a news update or a matchday briefing.
struct ContentItem: Identifiable, Codable, Hashable {
    let id: UUID
    let teamId: String
    let type: ContentType
    let headline: String
    let body: String
    let kickoffTime: Date?
    let emotionalContext: String?
    let publishedAt: Date

    // Raw JSONB — decoded differently based on `type`.
    // Internal access so MockData.swift can construct instances directly.
    let talkingPointsRaw: TalkingPointsPayload

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

    // MARK: - Talking Points Access

    var regularTalkingPoints: [String] {
        switch talkingPointsRaw {
        case .stringArray(let points):
            return points
        case .matchday(let data):
            return data.regular
        }
    }

    var postMatchCheatSheet: PostMatchCheatSheet? {
        guard type == .matchday else { return nil }
        if case .matchday(let data) = talkingPointsRaw {
            return data.postMatch
        }
        return nil
    }

    var matchdayMetadata: MatchdayMetadata? {
        guard type == .matchday else { return nil }
        if case .matchday(let data) = talkingPointsRaw {
            return data.metadata
        }
        return nil
    }

    static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Matchday JSONB Types (Contract 3)

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

// MARK: - Dual-Format Decoder

/// Handles the dual JSON format for `talking_points`:
/// - News items: plain `[String]`
/// - Matchday items: `MatchdayTalkingPoints` object
enum TalkingPointsPayload: Codable {
    case stringArray([String])
    case matchday(MatchdayTalkingPoints)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self = .stringArray(array)
            return
        }
        if let matchday = try? container.decode(MatchdayTalkingPoints.self) {
            self = .matchday(matchday)
            return
        }
        throw DecodingError.typeMismatch(
            TalkingPointsPayload.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "talking_points must be either [String] or MatchdayTalkingPoints object"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .stringArray(let array):
            try container.encode(array)
        case .matchday(let data):
            try container.encode(data)
        }
    }
}
