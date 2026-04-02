import Foundation

/// Manages saved talking points. Uses UserDefaults for lightweight persistence.
/// Only stores plain text strings — no personal data, no network calls.
class SavedPointsService {
    static let shared = SavedPointsService()

    private let key = "savedTalkingPoints"

    /// All saved points
    var savedPoints: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// Check if a point is saved
    func isSaved(_ point: String) -> Bool {
        savedPoints.contains(point)
    }

    /// Toggle save/unsave
    func toggle(_ point: String) {
        var points = savedPoints
        if let index = points.firstIndex(of: point) {
            points.remove(at: index)
        } else {
            points.insert(point, at: 0)
        }
        UserDefaults.standard.set(points, forKey: key)
    }

    /// Remove a specific point
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
