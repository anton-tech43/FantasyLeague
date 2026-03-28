import Foundation

// TODO: Implement in I4 — Supabase REST per Contract 5
class APIClient {
    static let shared = APIClient()

    // These values will be set from the live Supabase project
    private let baseURL = URL(string: "https://YOUR_PROJECT.supabase.co/rest/v1")!
    private let apiKey = "SUPABASE_ANON_KEY_HERE"

    private var headers: [String: String] {
        [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    /// Fetch published content for a team, paginated
    func fetchFeed(teamId: String, limit: Int = 20, offset: Int = 0) async throws -> [ContentItem] {
        // TODO: Implement
        return []
    }

    /// Fetch a single content item by ID (for deep linking from push notifications)
    func fetchItem(id: UUID) async throws -> ContentItem? {
        // TODO: Implement
        return nil
    }

    /// Register a device token with the backend
    func registerToken(_ token: String, teamId: String) async throws {
        // TODO: Implement
    }
}
