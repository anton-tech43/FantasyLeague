import Foundation

class APIClient {
    static let shared = APIClient()

    // SECURITY: Credentials injected at build time via Configuration.xcconfig → Info.plist
    // When credentials are missing (dev without backend), API calls throw and the app falls back to mock data.
    //
    // NOTE: We read SUPABASE_HOST (bare hostname) and prepend "https://" here. Earlier configs stored
    // a full URL, which broke silently because xcconfig/Info.plist treated `//` in `https://` as a
    // comment marker — the host got truncated and every API call resolved to "https://rest/v1/...".
    var isConfigured: Bool { _baseURL != nil }

    // APNs token environment. The backend uses this to route push notifications
    // to the correct Apple endpoint:
    //   - DEBUG (Xcode-built builds → development APNs sandbox tokens)
    //   - RELEASE (TestFlight + App Store → production APNs tokens)
    // Sent on every device_tokens insert; without it, the column defaults to
    // 'development' on the DB side and production builds get 0 pushes.
    static var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    private static func resolveHost() -> String? {
        guard let host = Bundle.main.infoDictionary?["SUPABASE_HOST"] as? String,
              !host.isEmpty,
              !host.contains("YOUR_PROJECT"),
              !host.contains("xxxxx") else {
            return nil
        }
        return host
    }

    private let _baseURL: URL? = {
        guard let host = APIClient.resolveHost(),
              let url = URL(string: "https://\(host)/rest/v1") else {
            print("⚠️ SUPABASE_HOST not set, running in offline/mock mode")
            return nil
        }
        return url
    }()

    private func requireBaseURL() throws -> URL {
        guard let url = _baseURL else { throw APIError.notConfigured }
        return url
    }

    private let _functionsBaseURL: URL? = {
        guard let host = APIClient.resolveHost(),
              let url = URL(string: "https://\(host)/functions/v1") else {
            return nil
        }
        return url
    }()

    private func requireFunctionsBaseURL() throws -> URL {
        guard let url = _functionsBaseURL else { throw APIError.notConfigured }
        return url
    }

    private let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.contains("YOUR_ANON_KEY") else {
            print("⚠️ SUPABASE_ANON_KEY not set, running in offline/mock mode")
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

    /// All columns needed for ContentItem decoding (base + everyone + immersive + analogy)
    private static let contentSelectColumns = "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at,everyone_talking,everyone_talking_headline,everyone_talking_body,everyone_talking_talking_points,worth_knowing,immersive_headline,immersive_context,immersive_context_fallback,analogy_reviewed,analogy_approved,analogy_auto_published"

    /// Decode a JSON array of ContentItems, skipping any individual item that fails to decode.
    ///
    /// `JSONDecoder.decode([ContentItem].self, ...)` is all-or-nothing: one bad row throws and
    /// the entire feed is lost. That happened today with NULL `published_at` rows. Server-side
    /// filters help, but they're one guard against one specific class of failure. This helper
    /// turns a potential blank-feed crash into "you see 19 items instead of 20" — which is
    /// dramatically better UX. The bad item is logged in DEBUG so we still notice schema drift.
    private func decodeContentItems(from data: Data) throws -> [ContentItem] {
        // First parse as a heterogeneous array to get per-item JSON we can decode separately.
        let rawItems = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] ?? []
        var decoded: [ContentItem] = []
        decoded.reserveCapacity(rawItems.count)
        for (index, raw) in rawItems.enumerated() {
            do {
                let itemData = try JSONSerialization.data(withJSONObject: raw, options: [])
                let item = try decoder.decode(ContentItem.self, from: itemData)
                decoded.append(item)
            } catch {
                #if DEBUG
                let id = (raw as? [String: Any])?["id"] as? String ?? "unknown"
                print("⚠️ ContentItem decode failed at index \(index) (id=\(id)): \(error)")
                #endif
                // Continue: one bad row doesn't kill the feed.
            }
        }
        return decoded
    }

    func fetchFeed(teamId: String, limit: Int = 20, offset: Int = 0) async throws -> [ContentItem] {
        // `published_at=not.is.null` filter is critical: some legacy rows have
        // status='published' but published_at=NULL. Postgres sorts NULLs first
        // in DESC ordering, which would push genuinely fresh items below stale
        // ones in the feed. Plus the iOS Date decoder is non-optional — a NULL
        // would break the whole array decode. Belt and braces: server-side
        // filter + non-optional Date catch errors at both ends.
        let url = try buildURL(path: "content_items", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "published_at", value: "not.is.null"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "select", value: Self.contentSelectColumns)
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try decodeContentItems(from: data)
    }

    func fetchEveryoneFeed(limit: Int = 20, offset: Int = 0) async throws -> [ContentItem] {
        let url = try buildURL(path: "content_items", queryItems: [
            URLQueryItem(name: "everyone_talking", value: "eq.true"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "published_at", value: "not.is.null"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "select", value: Self.contentSelectColumns)
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try decodeContentItems(from: data)
    }

    func fetchItem(id: UUID) async throws -> ContentItem? {
        let url = try buildURL(path: "content_items", queryItems: [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "select", value: Self.contentSelectColumns)
        ])
        let request = makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        let items = try decodeContentItems(from: data)
        return items.first
    }

    // MARK: - Device Token

    func registerToken(_ token: String, teamId: String, tier: Int = 2) async throws {
        let url = try requireBaseURL().appendingPathComponent("device_tokens")
        let body: [String: Any] = [
            "team_id": teamId,
            "apns_token": token,
            "tier": tier,
            // Tells the server which APNs endpoint to use for this token.
            // Without this, the DB column defaults to 'development' and
            // App Store / TestFlight tokens get pushed to the sandbox endpoint
            // (which rejects them with 400, deactivating the token → no pushes).
            "apns_environment": APIClient.apnsEnvironment,
        ]
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

    // MARK: - Team Season State (post-onboarding Season Primer)

    /// Fetch the one-row season-state snapshot for the given team. Returns nil
    /// when there's no row yet (e.g., a brand-new team the routine hasn't
    /// generated for yet). The Season Primer view treats nil + thrown errors
    /// identically — both mean "skip the primer, go to feed".
    ///
    /// Uses direct REST (not the `team-season-state` Edge Function) because
    /// the function was deployed without `--no-verify-jwt` and the
    /// `sb_publishable_*` key model isn't JWT-encoded. Direct REST through
    /// PostgREST accepts the publishable key fine; the table has an RLS
    /// policy allowing public read.
    func fetchTeamSeasonState(teamId: String) async throws -> TeamSeasonState? {
        let url = try buildURL(path: "team_season_state", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "select", value: "team_id,phase,summary,key_fact,welcome_lines,next_fixture")
        ])
        var request = makeRequest(url: url)
        // Short timeout: the primer is on the user's first-launch critical path.
        // If the backend is slow, skip it rather than block onboarding completion.
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        let rows = try decoder.decode([TeamSeasonState].self, from: data)
        return rows.first
    }

    // MARK: - Insider items (V1.1 task C1)

    /// Fetch the N most recent insider items for a team, newest first.
    /// Used by both the "Things he doesn't know" card on His Team and the
    /// Feed empty-state surface when there's no news for the team.
    ///
    /// Returns an empty array if the team has no items yet (brand-new team
    /// the routine hasn't generated for yet, or a team that's been skipped
    /// for a few days). Callers treat empty-array and thrown-error
    /// identically — neither blocks the UI.
    func fetchInsiderItems(teamId: String, limit: Int = 5) async throws -> [InsiderItem] {
        let url = try buildURL(path: "team_insider_items", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "select", value: "id,team_id,type,title,body,source_url,published_at")
        ])
        var request = makeRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try decoder.decode([InsiderItem].self, from: data)
    }

    // MARK: - Delete My Data

    func deleteMyData(token: String) async throws {
        let url = try requireFunctionsBaseURL().appendingPathComponent("delete-my-data")
        let body = try JSONSerialization.data(withJSONObject: ["apns_token": token])
        let request = makeRequest(url: url, method: "POST", body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Helpers

    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: try requireBaseURL().appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
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
    case notConfigured
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "API not configured"
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "Server error (\(code))"
        }
    }
}
