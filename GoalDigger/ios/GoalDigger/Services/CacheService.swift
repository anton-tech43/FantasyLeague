import Foundation
import SwiftData

// MARK: - SwiftData Model for cached content

@Model
class CachedContentItem {
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
        self.kickoffTime = item.kickoffTime
        self.emotionalContext = item.emotionalContext
        self.publishedAt = item.publishedAt
        self.cachedAt = Date()

        // Encode talking_points as JSON data to preserve format
        let encoder = JSONEncoder()
        if let matchdayData = item.matchdayData {
            self.talkingPointsJSON = (try? encoder.encode(matchdayData)) ?? Data()
        } else {
            self.talkingPointsJSON = (try? encoder.encode(item.talkingPoints)) ?? Data()
        }
    }

    /// Convert back to ContentItem
    func toContentItem() -> ContentItem? {
        guard let contentType = ContentItem.ContentType(rawValue: type) else { return nil }

        let decoder = JSONDecoder()
        var talkingPoints: [String] = []
        var matchdayData: MatchdayTalkingPoints?

        if contentType == .matchday,
           let matchday = try? decoder.decode(MatchdayTalkingPoints.self, from: talkingPointsJSON) {
            matchdayData = matchday
            talkingPoints = matchday.regular
        } else if let strings = try? decoder.decode([String].self, from: talkingPointsJSON) {
            talkingPoints = strings
        }

        return ContentItem(
            id: id,
            teamId: teamId,
            type: contentType,
            headline: headline,
            body: body,
            talkingPoints: talkingPoints,
            matchdayData: matchdayData,
            kickoffTime: kickoffTime,
            emotionalContext: emotionalContext,
            publishedAt: publishedAt
        )
    }
}

// MARK: - Cache Service

class CacheService {
    static let shared = CacheService()

    private var container: ModelContainer?

    init() {
        do {
            let schema = Schema([CachedContentItem.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("[Cache] Failed to create container: \(error)")
            #endif
        }
    }

    /// Save content items to cache
    @MainActor
    func save(_ items: [ContentItem]) {
        guard let container else { return }
        let context = container.mainContext

        for item in items {
            let cached = CachedContentItem(from: item)
            context.insert(cached)
        }

        try? context.save()
    }

    /// Load cached content for a team, sorted by publishedAt descending
    @MainActor
    func load(teamId: String) -> [ContentItem] {
        guard let container else { return [] }
        let context = container.mainContext

        let descriptor = FetchDescriptor<CachedContentItem>(
            predicate: #Predicate { $0.teamId == teamId },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )

        guard let cached = try? context.fetch(descriptor) else { return [] }
        return cached.compactMap { $0.toContentItem() }
    }

    /// Clear all cached items for a team
    @MainActor
    func clear(teamId: String) {
        guard let container else { return }
        let context = container.mainContext

        let descriptor = FetchDescriptor<CachedContentItem>(
            predicate: #Predicate { $0.teamId == teamId }
        )

        if let items = try? context.fetch(descriptor) {
            for item in items {
                context.delete(item)
            }
            try? context.save()
        }
    }
}
