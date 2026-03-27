import Foundation
import SwiftData

/// SwiftData model for local caching of content items.
/// Used by CacheService to persist feed data for offline access.
@Model
final class CachedContentItem {
    @Attribute(.unique) var id: UUID
    var teamId: String
    var type: String
    var headline: String
    var body: String
    var talkingPointsJSON: Data
    var kickoffTime: Date?
    var emotionalContext: String?
    var publishedAt: Date
    var cachedAt: Date

    init(from item: ContentItem) {
        self.id = item.id
        self.teamId = item.teamId
        self.type = item.type.rawValue
        self.headline = item.headline
        self.body = item.body
        self.talkingPointsJSON = (try? JSONEncoder().encode(item.talkingPoints)) ?? Data()
        self.kickoffTime = item.kickoffTime
        self.emotionalContext = item.emotionalContext
        self.publishedAt = item.publishedAt
        self.cachedAt = Date()
    }

    func toContentItem() -> ContentItem {
        let points = (try? JSONDecoder().decode([String].self, from: talkingPointsJSON)) ?? []
        return ContentItem(
            id: id,
            teamId: teamId,
            type: ContentItem.ContentType(rawValue: type) ?? .news,
            headline: headline,
            body: body,
            talkingPoints: points,
            kickoffTime: kickoffTime,
            emotionalContext: emotionalContext,
            publishedAt: publishedAt
        )
    }
}
