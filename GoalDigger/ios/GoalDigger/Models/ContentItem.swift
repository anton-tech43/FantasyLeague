import Foundation

struct ContentItem: Identifiable, Codable, Hashable {
    let id: UUID
    let teamId: String
    let type: ContentType
    let headline: String
    let body: String
    let talkingPoints: [String]
    let kickoffTime: Date?
    let emotionalContext: String?
    let publishedAt: Date

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

    // MARK: - Contract 3: Dual-format talking_points decoder
    // The backend may send talking_points as either:
    //   1. An array of strings: ["point1", "point2"]
    //   2. An array of objects: [{"text": "point1"}, {"text": "point2"}]
    // This custom decoder handles both formats.

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

        // Dual-format decoder for talking_points
        if let stringArray = try? container.decode([String].self, forKey: .talkingPoints) {
            talkingPoints = stringArray
        } else if let objectArray = try? container.decode([TalkingPointObject].self, forKey: .talkingPoints) {
            talkingPoints = objectArray.map(\.text)
        } else {
            talkingPoints = []
        }
    }

    init(
        id: UUID,
        teamId: String,
        type: ContentType,
        headline: String,
        body: String,
        talkingPoints: [String],
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
        self.kickoffTime = kickoffTime
        self.emotionalContext = emotionalContext
        self.publishedAt = publishedAt
    }
}

/// Helper struct for decoding the object format of talking_points
private struct TalkingPointObject: Codable {
    let text: String
}
