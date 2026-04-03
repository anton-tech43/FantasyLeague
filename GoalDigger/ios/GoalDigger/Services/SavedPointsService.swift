import Foundation

// MARK: - SavedPointsService
// UserDefaults-backed storage for bookmarked talking points.
//
// Design decisions for other agents:
// - Simple UserDefaults storage (not SwiftData) — talking points are just strings
// - No sensitive data stored — just plain text talking points
// - Thread-safe via serial DispatchQueue
// - Capped at 100 saved points to prevent unbounded storage growth
// - Singleton pattern matches other services (APIClient, CacheService, NotificationService)

class SavedPointsService {
    static let shared = SavedPointsService()

    private let key = "savedTalkingPoints"
    private let queue = DispatchQueue(label: "com.goaldigger.savedpoints")
    private let maxSavedPoints = 100

    /// All saved talking points, most recent first
    var savedPoints: [String] {
        queue.sync {
            UserDefaults.standard.stringArray(forKey: key) ?? []
        }
    }

    /// Check if a talking point is already saved
    func isSaved(_ point: String) -> Bool {
        savedPoints.contains(point)
    }

    /// Toggle save state for a talking point
    func toggle(_ point: String) {
        queue.sync {
            var points = UserDefaults.standard.stringArray(forKey: key) ?? []
            if let index = points.firstIndex(of: point) {
                points.remove(at: index)
            } else {
                points.insert(point, at: 0)
                // Enforce storage limit
                if points.count > maxSavedPoints {
                    points = Array(points.prefix(maxSavedPoints))
                }
            }
            UserDefaults.standard.set(points, forKey: key)
        }
    }

    /// Remove a specific talking point
    func remove(_ point: String) {
        queue.sync {
            var points = UserDefaults.standard.stringArray(forKey: key) ?? []
            points.removeAll { $0 == point }
            UserDefaults.standard.set(points, forKey: key)
        }
    }

    /// Clear all saved points
    func clearAll() {
        queue.sync {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
