import Foundation

/// Loads and indexes the bundled glossary at startup. Look up via
/// `GlossaryService.shared.lookup(_:)`, which accepts a term name OR an alias.
final class GlossaryService {
    static let shared = GlossaryService()

    private(set) var terms: [GlossaryTerm] = []
    private(set) var lookupIndex: [String: GlossaryTerm] = [:]

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "glossary", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("⚠️ glossary.json missing from bundle")
            #endif
            return
        }
        do {
            let parsed = try JSONDecoder().decode([GlossaryTerm].self, from: data)
            terms = parsed
            var idx: [String: GlossaryTerm] = [:]
            for t in parsed {
                idx[t.term.lowercased()] = t
                for alias in t.aliases { idx[alias.lowercased()] = t }
            }
            lookupIndex = idx
        } catch {
            #if DEBUG
            print("⚠️ glossary decode failed: \(error)")
            #endif
        }
    }

    /// Case-insensitive lookup. Accepts term names and aliases.
    func lookup(_ word: String) -> GlossaryTerm? {
        lookupIndex[word.lowercased()]
    }

    /// Lookup by the stable id (which is the canonical term string).
    func lookup(id: String) -> GlossaryTerm? {
        lookupIndex[id.lowercased()]
    }
}
