import Foundation

/// A football term that's worth explaining inline. Loaded from the bundled
/// `glossary.json` resource at app launch via `GlossaryService`.
struct GlossaryTerm: Codable, Identifiable, Equatable {
    var id: String { term }
    let term: String
    let aliases: [String]
    let explanation: String
}
