import Foundation

struct ContentItem: Identifiable, Codable {
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

    // MARK: - Dual-format talking_points decoder (Contract 3)
    // Backend may return talking_points as either:
    //   ["string", "string"] — flat array
    //   [{"emoji": "...", "text": "..."}, ...] — object array
    // We normalize both to [String] for display.

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

        // Dual-format decoder
        if let strings = try? container.decode([String].self, forKey: .talkingPoints) {
            talkingPoints = strings
        } else if let objects = try? container.decode([TalkingPointObject].self, forKey: .talkingPoints) {
            talkingPoints = objects.map { "\($0.emoji) \($0.text)" }
        } else {
            talkingPoints = []
        }
    }
}

// Helper for object-format talking points
private struct TalkingPointObject: Codable {
    let emoji: String
    let text: String
}
