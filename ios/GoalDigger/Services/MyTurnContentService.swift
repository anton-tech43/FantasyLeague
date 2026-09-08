import Foundation
import Observation

/// Loads the three My Turn content files and keeps them current.
///
/// Order of precedence for each module:
///   1. a cached download in Application Support/MyTurn/<module>.json whose
///      contentVersion is newer than the bundled file's,
///   2. the bundled file in Resources/MyTurn (always present — offline floor).
///
/// `refresh()` reads the manifest from `my_turn_content` (module,
/// content_version), downloads only what is newer, writes it to the cache and
/// swaps it in. The previous cached version is kept as <module>.prev.json so a
/// bad batch can be rolled back server-side (publish the older version again)
/// without an app release. A failed fetch is not an error for the user.
///
/// contentVersion is "YYYY-MM-DD.N", so plain string comparison orders it.
@MainActor
@Observable
final class MyTurnContentService {
    static let shared = MyTurnContentService()

    private(set) var sayThis: SayThisContent
    private(set) var lingo: LingoContent
    private(set) var quiz: QuizContent

    private let decoder = JSONDecoder()
    private var lastRefresh: Date?

    private init() {
        // Bundled files are validated in CI; if one is missing the tab still
        // needs to render, so fall back to an empty module rather than crash.
        sayThis = Self.loadBest("saythis") ?? SayThisContent(contentVersion: "0", situations: [])
        lingo   = Self.loadBest("lingo")   ?? LingoContent(contentVersion: "0", terms: [])
        quiz    = Self.loadBest("quiz")    ?? QuizContent(contentVersion: "0", packs: [])
    }

    // MARK: Loading

    private static let cacheDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MyTurn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func bundledURL(_ module: String) -> URL? {
        Bundle.main.url(forResource: module, withExtension: "json", subdirectory: "MyTurn")
            ?? Bundle.main.url(forResource: module, withExtension: "json")
    }

    private static func cachedURL(_ module: String) -> URL { cacheDir.appendingPathComponent("\(module).json") }
    private static func previousURL(_ module: String) -> URL { cacheDir.appendingPathComponent("\(module).prev.json") }

    private static func version(of data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["contentVersion"] as? String
    }

    /// Newest of bundled vs cached, decoded. A cached file that fails to decode
    /// is deleted so it cannot poison future launches.
    private static func loadBest<T: Decodable>(_ module: String) -> T? {
        let decoder = JSONDecoder()
        let bundled = bundledURL(module).flatMap { try? Data(contentsOf: $0) }
        let cached = try? Data(contentsOf: cachedURL(module))
        var candidates: [(String, Data)] = []
        if let b = bundled, let v = version(of: b) { candidates.append((v, b)) }
        if let c = cached, let v = version(of: c) { candidates.append((v, c)) }
        for (_, data) in candidates.sorted(by: { $0.0 > $1.0 }) {
            if let decoded = try? decoder.decode(T.self, from: data) { return decoded }
            if data == cached { try? FileManager.default.removeItem(at: cachedURL(module)) }
        }
        return nil
    }

    var currentVersions: [String: String] {
        ["saythis": sayThis.contentVersion, "lingo": lingo.contentVersion,
         "quiz": quiz.contentVersion]
    }

    // MARK: Refresh

    private struct ManifestRow: Decodable {
        let module: String
        let content_version: String
    }
    private struct BodyRow: Decodable {
        let module: String
        let content_version: String
        let body: AnyJSON
    }
    /// Passes the JSON body through untouched so it can be written to disk
    /// byte-for-byte as the file the app would have shipped with.
    private struct AnyJSON: Decodable {
        let data: Data
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            let raw = try c.decode(RawJSON.self)
            data = try JSONSerialization.data(withJSONObject: raw.value, options: [.sortedKeys])
        }
    }
    private enum RawJSON: Decodable {
        case value(Any)
        var value: Any { if case .value(let v) = self { return v } else { return NSNull() } }
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let v = try? c.decode([String: RawJSON].self) { self = .value(v.mapValues(\.value)); return }
            if let v = try? c.decode([RawJSON].self) { self = .value(v.map(\.value)); return }
            if let v = try? c.decode(String.self) { self = .value(v); return }
            if let v = try? c.decode(Bool.self) { self = .value(v); return }
            if let v = try? c.decode(Int.self) { self = .value(v); return }
            if let v = try? c.decode(Double.self) { self = .value(v); return }
            self = .value(NSNull())
        }
    }

    /// Throttled to once an hour per process. Never throws to the caller.
    func refresh() async {
        if let last = lastRefresh, Date().timeIntervalSince(last) < 3600 { return }
        lastRefresh = Date()
        guard APIClient.shared.isConfigured else { return }
        do {
            let manifestData = try await APIClient.shared.rawGET(
                path: "my_turn_content", queryItems: [URLQueryItem(name: "select", value: "module,content_version")]
            )
            let rows = try decoder.decode([ManifestRow].self, from: manifestData)
            let mine = currentVersions
            let newer = rows.filter { row in
                guard let have = mine[row.module] else { return false }
                return row.content_version > have
            }
            guard !newer.isEmpty else { return }
            let list = newer.map(\.module).joined(separator: ",")
            let bodiesData = try await APIClient.shared.rawGET(
                path: "my_turn_content",
                queryItems: [URLQueryItem(name: "module", value: "in.(\(list))"),
                             URLQueryItem(name: "select", value: "module,content_version,body")]
            )
            let bodies = try decoder.decode([BodyRow].self, from: bodiesData)
            for row in bodies { apply(module: row.module, data: row.body.data) }
        } catch {
            #if DEBUG
            print("MyTurn refresh skipped: \(error)")
            #endif
        }
    }

    /// Decode first, write second, swap third — a body that does not decode
    /// never touches disk or memory.
    private func apply(module: String, data: Data) {
        switch module {
        case "saythis":
            guard let c = try? decoder.decode(SayThisContent.self, from: data) else { return }
            store(module, data); sayThis = c
        case "lingo":
            guard let c = try? decoder.decode(LingoContent.self, from: data) else { return }
            store(module, data); lingo = c
        case "quiz":
            guard let c = try? decoder.decode(QuizContent.self, from: data) else { return }
            store(module, data); quiz = c
        default:
            return
        }
    }

    private func store(_ module: String, _ data: Data) {
        let url = Self.cachedURL(module)
        let prev = Self.previousURL(module)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: prev)
            try? FileManager.default.moveItem(at: url, to: prev)
        }
        try? data.write(to: url, options: .atomic)
    }
}
