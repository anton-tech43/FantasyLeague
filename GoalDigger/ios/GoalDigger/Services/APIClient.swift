import Foundation

/// Supabase REST API client (Contract 5).
/// Full implementation in task I4. Currently returns mock data.
actor APIClient {
    static let shared = APIClient()

    // TODO: I4 — Replace with real Supabase URL and key from config
    private let baseURL = URL(string: "https://placeholder.supabase.co/rest/v1")!
    private let apiKey = "SUPABASE_ANON_KEY_PLACEHOLDER"

    private var headers: [String: String] {
        [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Fetch published content for a team, paginated
    func fetchFeed(teamId: String, limit: Int = 20, offset: Int = 0) async throws -> [ContentItem] {
        // TODO: I4 — Real Supabase REST query
        return []
    }

    /// Fetch a single content item by ID (for deep linking from push notifications)
    func fetchItem(id: UUID) async throws -> ContentItem? {
        // TODO: I4 — Real Supabase REST query
        return nil
    }

    /// Register a device token with the backend
    func registerToken(_ token: String, teamId: String) async throws {
        // TODO: I4 — POST to device_tokens
    }

    /// Update the team for an existing device token
    func updateTokenTeam(_ token: String, newTeamId: String) async throws {
        // TODO: I4 — PATCH device_tokens
    }
}
