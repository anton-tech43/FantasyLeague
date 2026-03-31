import Foundation

// MARK: - API Client (Contract 5: Supabase REST API)

class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://cvnvcywwpinkzakqmotg.supabase.co/rest/v1")!
    private let apiKey = "sb_publishable_ZDgqGDqRN_BuKQi_xqGfaw_7BBiWeTc"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Supabase returns ISO 8601 dates with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try with fractional seconds first
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Fall back to without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()

    private var defaultHeaders: [String: String] {
        [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }

    // MARK: - Fetch Feed (Paginated)

    /// Fetch published content for a team, paginated
    /// Contract 5: GET /rest/v1/content_items?team_id=eq.{team_id}&status=eq.published&order=published_at.desc
    func fetchFeed(teamId: String, limit: Int = 20, offset: Int = 0) async throws -> [ContentItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("content_items"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "select", value: "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at")
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        defaultHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode([ContentItem].self, from: data)
    }

    // MARK: - Fetch Single Item (Deep Link)

    /// Fetch a single content item by ID (for deep linking from push notifications)
    /// Contract 5: GET /rest/v1/content_items?id=eq.{uuid}&status=eq.published
    func fetchItem(id: UUID) async throws -> ContentItem? {
        var components = URLComponents(url: baseURL.appendingPathComponent("content_items"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "select", value: "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at")
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        defaultHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let items = try decoder.decode([ContentItem].self, from: data)
        return items.first
    }

    // MARK: - Register Device Token

    /// Register a device token with the backend
    /// Contract 5: POST /rest/v1/device_tokens with Prefer: resolution=merge-duplicates
    func registerToken(_ token: String, teamId: String) async throws {
        let url = baseURL.appendingPathComponent("device_tokens")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        defaultHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: String] = [
            "team_id": teamId,
            "apns_token": token
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Update Team (Change Team)

    /// Update the team for a device token
    /// Contract 5: PATCH /rest/v1/device_tokens?apns_token=eq.{token}
    func updateTeam(token: String, newTeamId: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("device_tokens"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "apns_token", value: "eq.\(token)")
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        defaultHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body: [String: String] = [
            "team_id": newTeamId,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
