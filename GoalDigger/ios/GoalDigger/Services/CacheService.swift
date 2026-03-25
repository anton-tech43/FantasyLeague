import Foundation
import SwiftData

// MARK: - SwiftData Model

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

    init(
        id: UUID,
        teamId: String,
        type: String,
        headline: String,
        body: String,
        talkingPointsJSON: Data,
        kickoffTime: Date?,
        emotionalContext: String?,
        publishedAt: Date,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.teamId = teamId
        self.type = type
        self.headline = headline
        self.body = body
        self.talkingPointsJSON = talkingPointsJSON
        self.kickoffTime = kickoffTime
        self.emotionalContext = emotionalContext
        self.publishedAt = publishedAt
        self.cachedAt = cachedAt
    }

    /// Convert back to a ContentItem for the UI layer.
    func toContentItem() -> ContentItem? {
        guard let contentType = ContentItem.ContentType(rawValue: type) else { return nil }
        guard let payload = try? JSONDecoder().decode(TalkingPointsPayload.self, from: talkingPointsJSON) else { return nil }

        return ContentItem(
            id: id,
            teamId: teamId,
            type: contentType,
            headline: headline,
            body: body,
            kickoffTime: kickoffTime,
            emotionalContext: emotionalContext,
            publishedAt: publishedAt,
            talkingPointsRaw: payload
        )
    }
}

// MARK: - Cache Service

actor CacheService {
    static let shared = CacheService()

    /// Cache an array of ContentItems into SwiftData.
    func cacheItems(_ items: [ContentItem], context: ModelContext) async {
        await MainActor.run {
            for item in items {
                guard let jsonData = try? JSONEncoder().encode(item.talkingPointsRaw) else { continue }

                let cached = CachedContentItem(
                    id: item.id,
                    teamId: item.teamId,
                    type: item.type.rawValue,
                    headline: item.headline,
                    body: item.body,
                    talkingPointsJSON: jsonData,
                    kickoffTime: item.kickoffTime,
                    emotionalContext: item.emotionalContext,
                    publishedAt: item.publishedAt
                )
                context.insert(cached)
            }
            try? context.save()
        }
    }

    /// Load cached items for a given team, sorted by publishedAt descending.
    func loadCachedItems(teamId: String, context: ModelContext) async -> [CachedContentItem] {
        await MainActor.run {
            let descriptor = FetchDescriptor<CachedContentItem>(
                predicate: #Predicate { $0.teamId == teamId },
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            return (try? context.fetch(descriptor)) ?? []
        }
    }

    /// Delete items older than 30 days.
    func purgeOldItems(context: ModelContext) async {
        await MainActor.run {
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let descriptor = FetchDescriptor<CachedContentItem>(
                predicate: #Predicate { $0.cachedAt < cutoff }
            )
            if let old = try? context.fetch(descriptor) {
                for item in old {
                    context.delete(item)
                }
                try? context.save()
            }
        }
    }

    /// Clear all cached items (used on team switch).
    func clearAll(context: ModelContext) {
        try? context.delete(model: CachedContentItem.self)
        try? context.save()
    }
}
