import Foundation
import SwiftData

/// Local cache using SwiftData for offline access.
/// Full implementation in task I5.
actor CacheService {
    static let shared = CacheService()

    /// Cache an array of content items
    func cache(_ items: [ContentItem], context: ModelContext) {
        // TODO: I5 — Upsert into SwiftData
    }

    /// Retrieve cached items for a team
    func cachedItems(teamId: String, context: ModelContext) -> [ContentItem] {
        // TODO: I5 — Query SwiftData
        return []
    }

    /// Clear old cached items (older than 7 days)
    func pruneOldItems(context: ModelContext) {
        // TODO: I5 — Delete stale SwiftData records
    }
}
