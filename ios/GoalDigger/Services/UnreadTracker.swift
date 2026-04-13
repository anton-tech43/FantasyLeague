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
    func totalUnread(
        activeContext: FeedContext,
        teamItems: [ContentItem],
        everyoneItems: [ContentItem],
        selectedTeam: Team?
    ) -> Int {
        var total = 0
        // Count unread for team context if not active
        if let team = selectedTeam, activeContext != .team(team) {
            total += unreadCount(for: .team(team), items: teamItems)
        }
        // Count unread for everyone context if not active
        if activeContext != .everyoneTalking {
            total += unreadCount(for: .everyoneTalking, items: everyoneItems)
        }
        return total
    }

    /// Formatted aggregate badge text for the pill. Returns nil if zero.
    func aggregateBadgeText(
        activeContext: FeedContext,
        teamItems: [ContentItem],
        everyoneItems: [ContentItem],
        selectedTeam: Team?
    ) -> String? {
        let total = totalUnread(
            activeContext: activeContext,
            teamItems: teamItems,
            everyoneItems: everyoneItems,
            selectedTeam: selectedTeam
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
