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
    private static let contentSelectColumns = "id,team_id,type,headline,body,talking_points,kickoff_time,emotional_context,published_at,everyone_talking,everyone_talking_headline,everyone_talking_body,everyone_talking_talking_points,worth_knowing,immersive_headline,immersive_context,immersive_context_fallback,analogy_reviewed,analogy_approved,analogy_auto_published,affected_team_ids,preview_fixture_id"

    /// Decode a JSON array of ContentItems, skipping any individual item that fails to decode.
    ///
    /// `JSONDecoder.decode([ContentItem].self, ...)` is all-or-nothing: one bad row throws and
    /// the entire feed is lost. That happened today with NULL `published_at` rows. Server-side
    /// filters help, but they're one guard against one specific class of failure. This helper
    /// turns a potential blank-feed crash into "you see 19 items instead of 20" — which is
    /// dramatically better UX. The bad item is logged in DEBUG so we still notice schema drift.
    private func decodeContentItems(from data: Data) throws -> [ContentItem] {
        try decodeArrayLoosely(data: data)
    }

    /// Decode a JSON array, skipping any individual item that fails to decode.
    /// `JSONDecoder.decode([T].self, ...)` is all-or-nothing: one bad row
    /// throws and the entire response is lost. This helper turns a potential
    /// blank-feed crash into "you see N-1 items instead of N" — much better
    /// UX. The bad item is logged in DEBUG so schema drift is still visible.
    /// Used by `fetchFeed`, `fetchEveryoneFeed`, and `fetchInsiderItems` —
    /// any list endpoint where future schema changes could trip older
    /// clients on production data they don't yet recognize.
    private func decodeArrayLoosely<T: Decodable>(data: Data) throws -> [T] {
        let rawItems = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] ?? []
        var decoded: [T] = []
        decoded.reserveCapacity(rawItems.count)
        for (index, raw) in rawItems.enumerated() {
            do {
                let itemData = try JSONSerialization.data(withJSONObject: raw, options: [])
                let item = try decoder.decode(T.self, from: itemData)
                decoded.append(item)
            } catch {
                #if DEBUG
                let id = (raw as? [String: Any])?["id"] as? String ?? "unknown"
                print("⚠️ \(T.self) decode failed at index \(index) (id=\(id)): \(error)")
                #endif
                // Continue: one bad row doesn't kill the response.
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

    /// Register or update a device token. V2.2: a device may follow up to 2 PL
    /// clubs (`teamIds`) and up to 2 WC countries (`countryIds`), all equal. At
    /// least one entity must be present — caller responsibility.
    ///
    /// The FULL arrays are always sent, so a *removed* follow is dropped by the
    /// merge-duplicates replace. The legacy scalar `team_id`/`country_id`
    /// columns are mirrored to the first array element (or explicitly NULLed
    /// when empty) so the scalar push-query clause stays consistent with the
    /// arrays and a removal can't be defeated by a stale scalar.
    func registerToken(_ token: String,
                       teamIds: [String],
                       countryIds: [String],
                       tier: Int = 2) async throws {
        // SEC-1/2: register via the SECURITY DEFINER RPC (migration 071), not a
        // direct table upsert. The RPC runs as definer and does the full
        // follow-set upsert server-side, so the app needs only EXECUTE — no anon
        // SELECT/INSERT/UPDATE on device_tokens (which let anyone with the
        // publishable key read/tamper every row). The scalar columns are mirrored
        // to array[0] inside the RPC. apns_environment tells the server which
        // APNs endpoint to use (else dev/prod mismatch → 400 → token deactivated).
        let url = try requireBaseURL().appendingPathComponent("rpc/register_device_token")
        let body: [String: Any] = [
            "p_apns_token": token,
            "p_team_ids": teamIds,
            "p_country_ids": countryIds,
            "p_tier": tier,
            "p_apns_environment": APIClient.apnsEnvironment,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "POST", body: bodyData)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    /// Register a Live Activity push token. `kind` is "push_to_start" (per
    /// install — backend starts the activity at kickoff; fixtureId nil) or
    /// "update" (per running activity — backend updates/ends it; fixtureId set).
    /// SEC-3: registers via the SECURITY DEFINER RPC (migration 071), not a
    /// direct table upsert, so anon needs no access to live_activity_tokens.
    /// V2.2: `countryIds` carries every followed WC country so the single
    /// push-to-start token triggers the Live Activity for any of them.
    func registerLiveActivityToken(_ token: String,
                                   kind: String,
                                   fixtureId: Int?,
                                   countryIds: [String]) async throws {
        let url = try requireBaseURL().appendingPathComponent("rpc/register_la_token")
        let body: [String: Any] = [
            "p_token": token,
            "p_kind": kind,
            "p_fixture_id": fixtureId ?? NSNull(),
            "p_country_ids": countryIds,
            "p_apns_environment": APIClient.apnsEnvironment,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "POST", body: bodyData)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }

    // updateTokenTeam / updateTokenCountry were retired in V2.2: the partial
    // PATCH couldn't express the multi-follow arrays or NULL a removed scalar.
    // Settings now does a full re-register via
    // NotificationService.reregisterForFollowChange (one write path).

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
            URLQueryItem(name: "select", value: "team_id,phase,state_line,feeling_line,next_fixture,next_fixtures")
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
        // Loose decode: one bad row (e.g., a new type enum value added
        // server-side before iOS knows about it) doesn't sink the entire
        // response. The user just sees fewer items.
        return try decodeArrayLoosely(data: data)
    }

    /// Fetch the latest insider item of EACH type (stat, history, oddity,
    /// anecdote) for a team. Returns up to 4 items in render order: stat,
    /// history, oddity, anecdote (3 "fun facts" then the anecdote). Missing
    /// types are simply absent from the array — the caller renders whatever
    /// it gets. Used by the redesigned "Things he doesn't know" section on
    /// the team page (TeamPageView).
    ///
    /// One REST call: latest 40 rows, picked client-side. 40 is a safe
    /// ceiling — even if every row happened to be the same type we'd still
    /// find the latest of each other type within the daily-rotation window.
    func fetchInsiderSet(teamId: String) async throws -> [InsiderItem] {
        let url = try buildURL(path: "team_insider_items", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "select", value: "id,team_id,type,title,body,source_url,published_at"),
        ])
        var request = makeRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        let all: [InsiderItem] = try decodeArrayLoosely(data: data)

        // Pick the most recent of each type in render order.
        let order: [InsiderItem.ItemType] = [.stat, .history, .oddity, .anecdote]
        return order.compactMap { t in all.first(where: { $0.type == t }) }
    }

    /// Fetch content_items for this team that link to a specific upcoming
    /// fixture via preview_fixture_id. Used by the Calendar tab to map a
    /// fixture row to its preview ContentDetailView. Returns an empty
    /// array on error or for teams with no previews seeded (which is
    /// most teams pre-V1.1). One small REST call, payload bounded by the
    /// number of upcoming fixtures (~3-6 per WC country, 0 for PL clubs).
    func fetchPreviewItems(teamId: String) async throws -> [ContentItem] {
        let url = try buildURL(path: "content_items", queryItems: [
            URLQueryItem(name: "team_id", value: "eq.\(teamId)"),
            URLQueryItem(name: "preview_fixture_id", value: "not.is.null"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "order", value: "published_at.desc"),
            URLQueryItem(name: "limit", value: "20"),
        ])
        var request = makeRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try decodeArrayLoosely(data: data)
    }

    // MARK: - Live match brief (V1.1 task C5)

    /// Fetch the current live match brief for the team — the LiveMatchCard
    /// surface that polls every 60s during a live window.
    ///
    /// Goes through the live-brief-current Edge Function (NOT direct REST)
    /// because the function holds the "is there a live match right now?"
    /// logic — it joins match_status_state's kickoff window with
    /// live_match_briefs and returns 204 if no live window is active. iOS
    /// just polls; the server decides whether to render.
    ///
    /// Returns nil on 204 (expected — no live match for this team), and
    /// throws on real errors. Callers (FeedView) suppress nil + thrown
    /// errors identically — neither blocks the feed render.
    func fetchCurrentLiveBrief(teamId: String) async throws -> LiveMatchBrief? {
        let base = try requireFunctionsBaseURL()
        guard var components = URLComponents(url: base.appendingPathComponent("live-brief-current"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "team_id", value: teamId)]
        guard let url = components.url else { throw APIError.invalidResponse }
        var request = makeRequest(url: url)
        // Tight timeout: poll cadence is 60s, no point waiting longer than
        // 8s for a response we'll re-request shortly.
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 204 {
            return nil   // No live match in window — expected, not an error.
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        return try decoder.decode(LiveMatchBrief.self, from: data)
    }

    /// Current live match for the user's country (from match_status_state),
    /// for the Live Activity foreground-start fallback. Returns nil on 204
    /// (no live match). Mirrors fetchCurrentLiveBrief's envelope.
    func fetchCurrentLiveMatch(countryId: String) async throws -> LiveMatchSnapshot? {
        let base = try requireFunctionsBaseURL()
        guard var components = URLComponents(url: base.appendingPathComponent("live-match-current"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "country_id", value: countryId)]
        guard let url = components.url else { throw APIError.invalidResponse }
        var request = makeRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if httpResponse.statusCode == 204 { return nil }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        return try decoder.decode(LiveMatchSnapshot.self, from: data)
    }

    // MARK: - Saturday Quiz (V1.1 task C3)

    /// Fetch the freshest Saturday Quiz for the team, if one was published
    /// within the last 36 hours (Saturday 07:00 UTC through Sunday 19:00 UTC).
    ///
    /// Goes through the quiz-current Edge Function (NOT direct REST) for two
    /// reasons: (1) the freshness window logic lives server-side so iOS
    /// stays simple, (2) symmetric envelope with fetchCurrentLiveBrief —
    /// both return nil on 204, throw on real errors. T3+ tier-gated; the
    /// caller decides whether to invoke this at all.
    ///
    /// Returns nil on 204 (expected outside Sat/Sun window). Callers
    /// suppress nil + thrown errors identically — neither blocks the feed.
    func fetchCurrentQuiz(teamId: String) async throws -> SaturdayQuiz? {
        let base = try requireFunctionsBaseURL()
        guard var components = URLComponents(url: base.appendingPathComponent("quiz-current"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "team_id", value: teamId)]
        guard let url = components.url else { throw APIError.invalidResponse }
        var request = makeRequest(url: url)
        // Quiz is fetched once on view load — no poll loop. 10s timeout is
        // generous; if the request takes longer we just skip the card.
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 204 {
            return nil   // No quiz in window — expected outside Sat/Sun.
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        return try decoder.decode(SaturdayQuiz.self, from: data)
    }

    // MARK: - Delete My Data

    func deleteMyData(token: String) async throws {
        let url = try requireFunctionsBaseURL().appendingPathComponent("delete-my-data")
        // SEC-6: also send the Live Activity push-to-start token so the server
        // deletes that row too (it holds followed-country data under a different
        // token). Best-effort — omitted if the device never vended one.
        var payload: [String: Any] = ["apns_token": token]
        if let laToken = UserDefaults.standard.string(forKey: "liveActivityPushToStartToken"),
           !laToken.isEmpty {
            payload["la_token"] = laToken
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        // 404 (no token row) or 400 "Invalid token format" (iOS-17+ extended
        // device-token rejected by the server's strict 64-char-hex regex) both
        // mean her token isn't stored server-side. Same end state as a real
        // delete → return success. Other 400s (missing field, malformed JSON)
        // do not contain this body and still throw via validateResponse.
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return }
            if http.statusCode == 400,
               let body = String(data: data, encoding: .utf8),
               body.contains("Invalid token format") {
                return
            }
        }
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
