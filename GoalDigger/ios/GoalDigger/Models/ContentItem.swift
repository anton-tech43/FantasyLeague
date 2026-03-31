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

    // MARK: - Contract 3: Dual-format talking_points
    // News items: talking_points is a simple [String]
    // Matchday items: talking_points is a MatchdayTalkingPoints object

    /// Raw string array — populated for news items, or from .regular for matchday
    let talkingPoints: [String]

    /// Structured matchday data — only populated for matchday items
    let matchdayData: MatchdayTalkingPoints?

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
        case talkingPoints = "talking_points"
        case kickoffTime = "kickoff_time"
        case emotionalContext = "emotional_context"
        case publishedAt = "published_at"
    }

    // MARK: - Computed Properties

    /// Talking points for display — works for both news and matchday
    var regularTalkingPoints: [String] {
        switch type {
        case .news:
            return talkingPoints
        case .matchday:
            return matchdayData?.regular ?? talkingPoints
        }
    }

    /// Post-match cheat sheet — only available for matchday items
    var postMatchCheatSheet: PostMatchCheatSheet? {
        guard type == .matchday else { return nil }
        return matchdayData?.postMatch
    }

    /// Matchday metadata — only available for matchday items
    var matchdayMetadata: MatchdayMetadata? {
        guard type == .matchday else { return nil }
        return matchdayData?.metadata
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        teamId = try container.decode(String.self, forKey: .teamId)
        type = try container.decode(ContentType.self, forKey: .type)
        headline = try container.decode(String.self, forKey: .headline)
        body = try container.decode(String.self, forKey: .body)
        kickoffTime = try container.decodeIfPresent(Date.self, forKey: .kickoffTime)
        emotionalContext = try container.decodeIfPresent(String.self, forKey: .emotionalContext)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)

        // Contract 3 dual-format decoder:
        // Try matchday structured object first, then fall back to simple string array
        if let matchday = try? container.decode(MatchdayTalkingPoints.self, forKey: .talkingPoints) {
            matchdayData = matchday
            talkingPoints = matchday.regular
        } else if let strings = try? container.decode([String].self, forKey: .talkingPoints) {
            matchdayData = nil
            talkingPoints = strings
        } else {
            matchdayData = nil
            talkingPoints = []
        }
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(teamId, forKey: .teamId)
        try container.encode(type, forKey: .type)
        try container.encode(headline, forKey: .headline)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(kickoffTime, forKey: .kickoffTime)
        try container.encodeIfPresent(emotionalContext, forKey: .emotionalContext)
        try container.encode(publishedAt, forKey: .publishedAt)

        if let matchdayData {
            try container.encode(matchdayData, forKey: .talkingPoints)
        } else {
            try container.encode(talkingPoints, forKey: .talkingPoints)
        }
    }

    // MARK: - Memberwise Init (for mock data)

    init(
        id: UUID,
        teamId: String,
        type: ContentType,
        headline: String,
        body: String,
        talkingPoints: [String],
        matchdayData: MatchdayTalkingPoints? = nil,
        kickoffTime: Date? = nil,
        emotionalContext: String? = nil,
        publishedAt: Date
    ) {
        self.id = id
        self.teamId = teamId
        self.type = type
        self.headline = headline
        self.body = body
        self.talkingPoints = talkingPoints
        self.matchdayData = matchdayData
        self.kickoffTime = kickoffTime
        self.emotionalContext = emotionalContext
        self.publishedAt = publishedAt
    }
}

// MARK: - Matchday Talking Points (Contract 3)

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
    let preMatchMood: String    // "confident", "nervous", "excited", "meh"
    let rivalryLevel: String    // "derby", "big_game", "normal", "dead_rubber"

    enum CodingKeys: String, CodingKey {
        case preMatchMood = "pre_match_mood"
        case rivalryLevel = "rivalry_level"
    }
}
