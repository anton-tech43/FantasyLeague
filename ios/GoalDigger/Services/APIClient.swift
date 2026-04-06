import Foundation

class APIClient {
    static let shared = APIClient()

    // SECURITY: Credentials injected at build time via Configuration.xcconfig → Info.plist
    // When credentials are missing (dev without backend), API calls throw and the app falls back to mock data.
    var isConfigured: Bool { _baseURL != nil }

    private let _baseURL: URL? = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !urlString.isEmpty,
              !urlString.contains("YOUR_PROJECT"),
              !urlString.contains("xxxxx"),
              let url = URL(string: urlString + "/rest/v1") else {
            print("⚠️ SUPABASE_URL not set — running in offline/mock mode")
            return nil
        }
        return url
    }()

    private var baseURL: URL {
        guard let url = _baseURL else { fatalError("API called without configuration") }
        return url
    }

    private let _functionsBaseURL: URL? = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !urlString.isEmpty,
              !urlString.contains("YOUR_PROJECT"),
              !urlString.contains("xxxxx"),
              let url = URL(string: urlString + "/functions/v1") else {
            return nil
        }
        return url
    }()

    private var functionsBaseURL: URL {
        guard let url = _functionsBaseURL else { fatalError("API called without configuration") }
        return url
    }

    private let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.contains("YOUR_ANON_KEY") else {
            print("⚠️ SUPABASE_ANON_KEY not set — running in offline/mock mode")
            return ""
        }
        return key
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: dateString) { return date }
            if let date = plainFormatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()

    private func makeRequest(url: URL, method: String = "GET", body: Data? = nil, extraHeaders: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        return request
    }

    // MARK: - Feed

    func fetchFeed(teamId: String, limit: Int = 20, offset: Int = 0) async throws -> [ContentItem] {
        let url = try buildURL(path: "content_items", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "select", value: "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at")
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try decoder.decode([ContentItem].self, from: data)
    }

    func fetchItem(id: UUID) async throws -> ContentItem? {
        let url = try buildURL(path: "content_items", queryItems: [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "select", value: "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at")
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        let items = try decoder.decode([ContentItem].self, from: data)
        return items.first
    }

    // MARK: - Device Token

    func registerToken(_ token: String, teamId: String, tier: Int = 2) async throws {
        let url = baseURL.appendingPathComponent("device_tokens")
        let body: [String: Any] = ["team_id": teamId, "apns_token": token, "tier": tier]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(
            url: url,
            method: "POST",
            body: bodyData,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    func updateTokenTeam(_ token: String, newTeamId: String) async throws {
        let url = try buildURL(path: "device_tokens", queryItems: [
            URLQueryItem(name: "apns_token", value: "eq.\(token)")
        ])
        let body: [String: Any] = ["team_id": newTeamId, "updated_at": ISO8601DateFormatter().string(from: Date())]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "PATCH", body: bodyData)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    func updateTokenTier(_ token: String, tier: Int) async throws {
        let url = try buildURL(path: "device_tokens", queryItems: [
            URLQueryItem(name: "apns_token", value: "eq.\(token)")
        ])
        let body: [String: Any] = ["tier": tier, "updated_at": ISO8601DateFormatter().string(from: Date())]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "PATCH", body: bodyData)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Context Cards (Contract 10)

    func fetchPlayerCards(teamId: String) async throws -> [PlayerCard] {
        let url = try buildURL(path: "player_cards", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "select", value: "player_name,position,age,summary,vibe,form")
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try decoder.decode([PlayerCard].self, from: data)
    }

    func fetchTeamPage(teamId: String) async throws -> TeamPageContent? {
        let url = try buildURL(path: "team_pages", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "select", value: "content")
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        let pages = try decoder.decode([TeamPage].self, from: data)
        return pages.first?.content
    }

    // MARK: - Delete My Data

    func deleteMyData(token: String) async throws {
        let url = functionsBaseURL.appendingPathComponent("delete-my-data")
        let body = try JSONSerialization.data(withJSONObject: ["apns_token": token])
        let request = makeRequest(url: url, method: "POST", body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Helpers

    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        return url
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "Server error (\(code))"
        }
    }
}
