import Foundation

// MARK: - My Turn content models
//
// Four static, versioned JSON files: saythis.json, lingo.json, quiz.json,
// drills.json. Bundled with the app (Resources/MyTurn) so the tab works
// offline, and refreshed from `my_turn_content` when a newer contentVersion
// exists (see MyTurnContentService). The shapes below are the spec's data
// model, decoded strictly — the files are validated in CI by
// tools/myturn/validate_content.py, so a decode failure here is a build bug,
// not a content bug.

enum MyTurnModule: String, CaseIterable, Identifiable, Codable {
    case sayThis = "saythis"
    case lingo
    case quiz
    case drills

    var id: String { rawValue }

    /// Segment label. "Say This" is the longest; `SayThisView` falls back to
    /// "Lines" at the largest accessibility sizes rather than truncating.
    var label: String {
        switch self {
        case .sayThis: return "Say This"
        case .lingo:   return "Lingo"
        case .quiz:    return "Quiz"
        case .drills:  return "Drills"
        }
    }

    var shortLabel: String { self == .sayThis ? "Lines" : label }
}

// MARK: Say This

struct SayThisContent: Codable {
    let contentVersion: String
    let situations: [Situation]
}

enum SituationGroup: String, Codable, CaseIterable {
    case moments
    case howItsGoing = "how_its_going"
    case whenHeAsks = "when_he_asks"

    var title: String {
        switch self {
        case .moments:     return "Moments"
        case .howItsGoing: return "How it's going"
        case .whenHeAsks:  return "When he asks you"
        }
    }
}

struct Situation: Codable, Identifiable, Hashable {
    let id: String
    let group: SituationGroup
    let label: String
    let lines: [SayLine]
}

enum LineRisk: String, Codable {
    case safe, bold
    var label: String { self == .safe ? "Safe" : "Bold" }
}

struct SayLine: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let usage: String
    let risk: LineRisk
    /// Optional Lingo id when the line leans on a real football saying
    /// ("Clinical." → clinical-finish). The row shows the term as a chip that
    /// jumps to its Lingo entry, so the phrase is taught, not just quoted.
    let lingo: String?
}

// MARK: Lingo

struct LingoContent: Codable {
    let contentVersion: String
    let terms: [LingoTerm]
}

enum LingoCategory: String, Codable, CaseIterable {
    case rules
    case tactics
    case matchSituations = "match_situations"
    case culture

    var title: String {
        switch self {
        case .rules:           return "Rules"
        case .tactics:         return "Tactics"
        case .matchSituations: return "Match situations"
        case .culture:         return "Culture & slang"
        }
    }
}

struct LingoTerm: Codable, Identifiable, Hashable {
    let id: String
    let category: LingoCategory
    let term: String
    let meaning: String
    let heard: String
    /// A sentence she can say that uses the term — turns a definition into a
    /// tool. Required by the validator since 2026-09-08; optional here so an
    /// older cached file still decodes.
    let sayIt: String?
    let seeAlso: [String]?
}

// MARK: Quiz

struct QuizContent: Codable {
    let contentVersion: String
    let packs: [QuizPack]
}

struct QuizPack: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let questions: [MyTurnQuestion]

    /// "His Club" packs are keyed `club-<kebab club id>`; the Quiz tab shows
    /// exactly one of them, for the club selected in His Team.
    var isClubPack: Bool { id.hasPrefix("club-") }
}

/// What the line under a question is for. The app labels it accordingly.
enum QuestionUseType: String, Codable {
    case say, ask, impress

    var label: String {
        switch self {
        case .say:     return "Say it"
        case .ask:     return "Ask him"
        case .impress: return "To impress"
        }
    }
}

struct MyTurnQuestion: Codable, Identifiable, Hashable {
    let id: String
    let difficulty: Int
    let verified: Bool
    let question: String
    let options: [String]
    let answer: Int
    /// The fact, with the context a non-fan lacks (who this person is).
    let explanation: String
    /// Why she would ever need this — one line. CONTENT_PRINCIPLES.md §1.
    let why: String?
    /// The line: something to say, ask or impress with.
    let use: String?
    let useType: QuestionUseType?
    /// Optional photo URL for "Who is this?" questions. Only the live club
    /// pack sets it; static content ships no images.
    let image: String?

    init(id: String, difficulty: Int, verified: Bool = true, question: String, options: [String], answer: Int,
         explanation: String, why: String? = nil, use: String? = nil, useType: QuestionUseType? = nil, image: String? = nil) {
        self.id = id; self.difficulty = difficulty; self.verified = verified; self.question = question
        self.options = options; self.answer = answer; self.explanation = explanation
        self.why = why; self.use = use; self.useType = useType; self.image = image
    }
}

// MARK: Drills

struct DrillsContent: Codable {
    let contentVersion: String
    let decks: [DrillDeck]
}

enum DeckSource: String, Codable {
    case saythis, lingo
    case staticCards = "static"
}

struct DrillDeck: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let source: DeckSource
    let cards: [DrillCard]?
}

enum DrillFrontType: String, Codable {
    case image, text, kit
}

/// A home kit as colour + pattern. The app draws it (KitView) so all twenty
/// shirts share one silhouette — the spec's one hard rule for the Kits deck.
struct KitSpec: Codable, Hashable {
    let primary: String
    let secondary: String
    let pattern: KitPattern
    let shorts: String?
}

enum KitPattern: String, Codable {
    case plain, stripes, hoops, halves, sash, sleeves, pinstripes, quarters
}

/// `front` is a string for text/image cards and an object for kit cards.
enum DrillFront: Codable, Hashable {
    case text(String)
    case kit(KitSpec)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .text(s); return }
        self = .kit(try c.decode(KitSpec.self))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s): try c.encode(s)
        case .kit(let k):  try c.encode(k)
        }
    }

    var string: String? { if case .text(let s) = self { return s } else { return nil } }
    var kit: KitSpec? { if case .kit(let k) = self { return k } else { return nil } }
}

struct DrillCard: Codable, Identifiable, Hashable {
    let id: String
    let frontType: DrillFrontType
    let front: DrillFront
    let back: String
}
