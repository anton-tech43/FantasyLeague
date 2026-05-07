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

    /// Cache schema version. Bumped any time we change `ContentItem` in a way
    /// that breaks existing JSON-encoded cache rows (new required field, renamed
    /// field, type change). On read, rows with a stale version are filtered out
    /// and ignored — effectively purged. New rows are written with the current
    /// version. Default 1 covers all rows from before this field existed
    /// (SwiftData migrates them with default value).
    var schemaVersion: Int = CacheService.cacheSchemaVersion

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
        self.schemaVersion = CacheService.cacheSchemaVersion

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

    /// Bump this whenever `ContentItem` changes in a way that breaks existing
    /// cached JSON: new required field, renamed field, type change. On the
    /// next app launch after a bump, `purgeStaleVersionItems()` deletes
    /// every CachedContentItem with an older version — the user transparently
    /// re-fetches from the server.
    ///
    /// Bump history:
    ///   1 = initial
    static let cacheSchemaVersion: Int = 1

    /// Drop any cached rows that don't match the current schema version.
    /// Called on app launch (see GoalDiggerApp.swift) so cache poisoning from
    /// an older app build can't crash the current build's decoder.
    func purgeStaleVersionItems(in context: ModelContext) {
        let current = Self.cacheSchemaVersion
        let predicate = #Predicate<CachedContentItem> { $0.schemaVersion != current }
        let descriptor = FetchDescriptor<CachedContentItem>(predicate: predicate)
        if let stale = try? context.fetch(descriptor) {
            for item in stale { context.delete(item) }
            try? context.save()
        }
    }

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
