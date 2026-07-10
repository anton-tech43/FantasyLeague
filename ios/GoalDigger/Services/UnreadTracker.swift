import Foundation

/// Tracks per-context "last viewed" timestamps for unread badge counts.
/// Timestamps stored in UserDefaults. Counts computed from item publishedAt dates.
@Observable
class UnreadTracker {
    static let shared = UnreadTracker()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "unreadTracker_lastViewed_"

    /// Returns the last time the user viewed a given context's feed.
    func lastViewedAt(for context: FeedContext) -> Date {
        let key = keyPrefix + context.storageKey
        let timestamp = defaults.double(forKey: key)
        guard timestamp > 0 else { return .distantPast }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Mark a context as viewed right now. Clears unread count for that context.
    func markViewed(_ context: FeedContext) {
        let key = keyPrefix + context.storageKey
        defaults.set(Date().timeIntervalSince1970, forKey: key)
    }

    /// Count of items published after the last viewed timestamp for a context.
    func unreadCount(for context: FeedContext, items: [ContentItem]) -> Int {
        let lastViewed = lastViewedAt(for: context)
        return items.filter { $0.publishedAt > lastViewed }.count
    }

    /// Formatted badge text. Returns nil if count is 0.
    func badgeText(for context: FeedContext, items: [ContentItem]) -> String? {
        let count = unreadCount(for: context, items: items)
        guard count > 0 else { return nil }
        return count > 9 ? "9+" : "\(count)"
    }

    /// Total unread across all non-active contexts. Used for the pill aggregate badge.
    ///
    /// V2.0: country contexts now contribute symmetrically. A user with both
    /// a PL team and a WC country gets their cross-context badge to count
    /// both inactive contexts. Pass `countryItems: []` if the caller doesn't
    /// have a separate countryItems array loaded (e.g. FeedView in V2.0,
    /// which only loads one set of items for the active context) — the
    /// country contribution then resolves to zero and the badge under-
    /// reports for the inactive context. Splitting the lists is V2.1.
    func totalUnread(
        activeContext: FeedContext,
        teamItems: [ContentItem],
        countryItems: [ContentItem],
        everyoneItems: [ContentItem],
        selectedTeams: [Team],
        selectedCountries: [Country]
    ) -> Int {
        var total = 0
        // V2.2: every followed entity contributes, not just the primary.
        for team in selectedTeams where activeContext != .team(team) {
            total += unreadCount(for: .team(team), items: teamItems)
        }
        for country in selectedCountries where activeContext != .country(country) {
            total += unreadCount(for: .country(country), items: countryItems)
        }
        if activeContext != .everyoneTalking {
            total += unreadCount(for: .everyoneTalking, items: everyoneItems)
        }
        return total
    }

    /// Formatted aggregate badge text for the pill. Returns nil if zero.
    func aggregateBadgeText(
        activeContext: FeedContext,
        teamItems: [ContentItem],
        countryItems: [ContentItem],
        everyoneItems: [ContentItem],
        selectedTeams: [Team],
        selectedCountries: [Country]
    ) -> String? {
        let total = totalUnread(
            activeContext: activeContext,
            teamItems: teamItems,
            countryItems: countryItems,
            everyoneItems: everyoneItems,
            selectedTeams: selectedTeams,
            selectedCountries: selectedCountries
        )
        guard total > 0 else { return nil }
        return total > 9 ? "9+" : "\(total)"
    }

    /// Clear all tracked timestamps (used in clearAllData)
    func clearAll() {
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
