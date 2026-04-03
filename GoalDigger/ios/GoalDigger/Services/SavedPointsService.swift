import Foundation

// MARK: - SavedPointsService
// UserDefaults-backed storage for bookmarked talking points.
//
// Design decisions for other agents:
// - Simple UserDefaults storage (not SwiftData) — talking points are just strings
// - No sensitive data stored — just plain text talking points
// - Thread-safe: all operations are synchronous on UserDefaults
// - Singleton pattern matches other services (APIClient, CacheService, NotificationService)

class SavedPointsService {
    static let shared = SavedPointsService()

    private let key = "savedTalkingPoints"

    /// All saved talking points, most recent first
    var savedPoints: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// Check if a talking point is already saved
    func isSaved(_ point: String) -> Bool {
        savedPoints.contains(point)
    }

    /// Toggle save state for a talking point
    func toggle(_ point: String) {
        var points = savedPoints
        if let index = points.firstIndex(of: point) {
            points.remove(at: index)
        } else {
            points.insert(point, at: 0)
        }
        UserDefaults.standard.set(points, forKey: key)
    }

    /// Remove a specific talking point
    func remove(_ point: String) {
        var points = savedPoints
        points.removeAll { $0 == point }
        UserDefaults.standard.set(points, forKey: key)
    }

    /// Clear all saved points
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
