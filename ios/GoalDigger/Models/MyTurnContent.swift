import Foundation

// MARK: - My Turn content models
//
// Three static, versioned JSON files: saythis.json, lingo.json, quiz.json. Bundled with the app (Resources/MyTurn) so the tab works
// offline, and refreshed from `my_turn_content` when a newer contentVersion
// exists (see MyTurnContentService). The shapes below are the spec's data
// model, decoded strictly — the files are validated in CI by
// tools/myturn/validate_content.py, so a decode failure here is a build bug,
// not a content bug.

enum MyTurnModule: String, CaseIterable, Identifiable, Codable {
    // Order is the segment order. Quiz first (2026-09-09): it is the module a
    // newcomer can use before she knows anything, and the one that teaches the
    // faces and names the other two assume.
    case quiz
    case lingo
    case sayThis = "saythis"

    var id: String { rawValue }

    /// Segment label. "Say This" is the longest; `SayThisView` falls back to
    /// "Lines" at the largest accessibility sizes rather than truncating.
    var label: String {
        switch self {
        case .quiz:    return "Quiz"
        case .lingo:   return "Lingo"
        case .sayThis: return "Say This"
        }
    }

    var shortLabel: String { self == .sayThis ? "Lines" : label }

    /// Tolerant decoding. `MyTurnStore` persists the last module inside one
    /// JSON blob with everything else she has starred and scored; a value this
    /// enum no longer has ("drills", retired 2026-09-09) must not throw and take
    /// her whole state down with it.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MyTurnModule(rawValue: raw) ?? .quiz
    }
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
    /// Progression level, 1 upwards (2026-09-09). Level 1 is the first ten
    /// words a newcomer meets; the Lingo view shows it open and folds the rest,
    /// and flashcard practise starts there. Optional so an older cached file
    /// still decodes; treat nil as the top level.
    let level: Int?
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
