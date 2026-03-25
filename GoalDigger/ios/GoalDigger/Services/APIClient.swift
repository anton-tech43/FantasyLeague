import Foundation

/// Supabase REST API client. All endpoints per Contract 5.
/// Uses SUPABASE_ANON_KEY for both apikey header and Bearer auth.
actor APIClient {
    static let shared = APIClient()

    // MARK: - Configuration
    // TODO: Replace with real Supabase project values after backend deployment
    private let baseURL = "https://YOUR_PROJECT.supabase.co"
    private let apiKey = "YOUR_ANON_KEY"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds first
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }

            // Fallback without fractional seconds
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return d
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Fetch Feed (Paginated)

    func fetchFeed(teamId: String, limit: Int, offset: Int) async throws -> [ContentItem] {
        var components = URLComponents(string: "\(baseURL)/rest/v1/content_items")!
        components.queryItems = [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "select", value: "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at"),
        ]

        let request = authenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode([ContentItem].self, from: data)
    }

    // MARK: - Fetch Single Item (Deep Link)

    func fetchItem(id: UUID) async throws -> ContentItem? {
        var components = URLComponents(string: "\(baseURL)/rest/v1/content_items")!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "select", value: "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at"),
        ]

        let request = authenticatedRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let items = try decoder.decode([ContentItem].self, from: data)
        return items.first
    }

    // MARK: - Register Device Token

    func registerToken(_ apnsToken: String, teamId: String) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/device_tokens")!
        var request = authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: String] = [
            "team_id": teamId,
            "apns_token": apnsToken,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Update Token Team (Team Switch)

    func updateTokenTeam(_ apnsToken: String, newTeamId: String) async throws {
        var components = URLComponents(string: "\(baseURL)/rest/v1/device_tokens")!
        components.queryItems = [
            URLQueryItem(name: "apns_token", value: "eq.\(apnsToken)"),
        ]

        var request = authenticatedRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        let body: [String: String] = [
            "team_id": newTeamId,
            "updated_at": formatter.string(from: Date()),
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Helpers

    private func authenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code):
            return "Server returned status \(code)."
        }
    }
}
