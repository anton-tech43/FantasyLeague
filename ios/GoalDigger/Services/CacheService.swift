import Foundation
import SwiftData

@Model
class CachedContentItem {
    @Attribute(.unique) var id: UUID
    var teamId: String
    var type: String
    var headline: String
    var body: String
    var talkingPointsData: Data
    var kickoffTime: Date?
    var emotionalContext: String?
    var publishedAt: Date
    var cachedAt: Date

    /// Whether this item appears in the "Everyone's talking about" cross-team feed.
    var everyoneTalking: Bool = false

    init(from item: ContentItem) {
        self.id = item.id
        self.teamId = item.teamId
        self.type = item.type.rawValue
        self.headline = item.headline
        self.body = item.body
        self.kickoffTime = item.kickoffTime
        self.emotionalContext = item.emotionalContext
        self.publishedAt = item.publishedAt
        self.everyoneTalking = item.everyoneTalking
        self.cachedAt = Date()

        // Encode the whole ContentItem as raw data for lossless caching.
        // Use ISO8601 date encoding so decoding can use the same format.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.talkingPointsData = (try? encoder.encode(item)) ?? Data()
    }

    func toContentItem() -> ContentItem? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ContentItem.self, from: talkingPointsData)
    }
}

@MainActor
class CacheService {
    static let shared = CacheService()

    func upsertItems(_ items: [ContentItem], in context: ModelContext) {
        for item in items {
            let cached = CachedContentItem(from: item)
            context.insert(cached)
        }
        try? context.save()
    }

    func fetchCachedFeed(teamId: String, in context: ModelContext) -> [ContentItem] {
        let predicate = #Predicate<CachedContentItem> { $0.teamId == teamId }
        let sort = SortDescriptor<CachedContentItem>(\.publishedAt, order: .reverse)
        var descriptor = FetchDescriptor<CachedContentItem>(predicate: predicate, sortBy: [sort])
        descriptor.fetchLimit = 50

        guard let cached = try? context.fetch(descriptor) else { return [] }
        return cached.compactMap { $0.toContentItem() }
    }

    func fetchCachedEveryoneFeed(in context: ModelContext) -> [ContentItem] {
        let predicate = #Predicate<CachedContentItem> { $0.everyoneTalking == true }
        let sort = SortDescriptor<CachedContentItem>(\.publishedAt, order: .reverse)
        var descriptor = FetchDescriptor<CachedContentItem>(predicate: predicate, sortBy: [sort])
        descriptor.fetchLimit = 50

        guard let cached = try? context.fetch(descriptor) else { return [] }
        return cached.compactMap { $0.toContentItem() }
    }

    func purgeOldItems(in context: ModelContext) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let predicate = #Predicate<CachedContentItem> { $0.publishedAt < cutoff }
        let descriptor = FetchDescriptor<CachedContentItem>(predicate: predicate)

        if let old = try? context.fetch(descriptor) {
            for item in old { context.delete(item) }
            try? context.save()
        }
    }

    func clearAll(in context: ModelContext) {
        let descriptor = FetchDescriptor<CachedContentItem>()
        if let all = try? context.fetch(descriptor) {
            for item in all { context.delete(item) }
            try? context.save()
        }
    }
}
