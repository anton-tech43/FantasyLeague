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

extension LingoCategory {
    /// Short label for a row or a card corner. `title` is the section heading
    /// ("Match situations"); a tag needs one word.
    var tag: String {
        switch self {
        case .rules:           return "Rules"
        case .tactics:         return "Tactics"
        case .matchSituations: return "Match"
        case .culture:         return "Slang"
        }
    }
}

/// Who said the Overheard line, for the chip above the snippet.
///
/// Decoded strictly, like `LingoCategory`: a speaker this build does not know
/// is a content bug the validator catches before publish, not something to
/// paper over at runtime with a wrong-looking chip.
enum LingoSpeaker: String, Codable {
    case him, telly, chat, pundit

    /// `.him` is the personalise token the rest of My Turn uses, so the chip
    /// renders his name (or "Your partner" when she never gave one) once the
    /// view runs it through `appState.personalise`.
    var label: String {
        switch self {
        case .him:    return "[His name]"
        case .telly:  return "The telly"
        case .chat:   return "Group chat"
        case .pundit: return "The pundit"
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
    /// Difficulty, 1 upwards (2026-09-09). It stopped being a ladder on
    /// 2026-09-22 — there are no levels on screen any more — and is now only a
    /// sort key: a deck deals easy words before hard ones, and a category fold
    /// lists its words in this order. Optional so an older cached file still
    /// decodes; treat nil as the top level.
    let level: Int?

    // MARK: Overheard (2026-09-22)
    //
    // The round asks the reverse of a flashcard: he says a thing, what did he
    // mean. All optional, because a cached lingo.json published before the
    // overhaul has none of them — a term without them simply is not playable
    // (`LingoWeekendDeck.options`) and still reads fine in the word list.

    /// A realistic line someone would actually say, using the term.
    let overheard: String?
    /// The exact substring of `overheard` to bold, emitted by the build script
    /// so the view can bold with a plain `range(of:)` and no matching rules.
    let overheardTerm: String?
    let speaker: LingoSpeaker?
    /// The right answer: what he meant, in her words.
    let gist: String?
    /// Exactly two hand-written wrong answers, same length band as `gist`.
    let decoys: [String]?
    /// When this word is worth knowing: tags from `MatchContext.knownTags`.
    /// `[String]`, not an enum, so a publish can add a tag before the app
    /// knows it (an unknown tag simply never matches a context).
    let when: [String]?
    /// A word an English speaker works out from the words themselves
    /// ("kick-off", "own goal"). Never dealt in a round — asking a grown woman
    /// what half-time means is the app talking down to her — but still in the
    /// word list and in search, because "never dealt" is not "not a word".
    /// Optional, like the other fields added since launch, so a cached file
    /// written before the marker existed still decodes.
    let basic: Bool?
    /// How often the moment for this word's `sayIt` line actually arrives in
    /// one match: "anytime" (waiting for nothing on the pitch), "common" (most
    /// matches) or "rare" (a sending off, a shootout, a hat-trick). The line
    /// the round leaves her with is drawn only from the first two, because the
    /// app asks a week later whether she said it, and asking that about a line
    /// whose moment never came is asking about something that was never
    /// possible. `String?` rather than an enum for the same reason `when` is
    /// `[String]`: a publish can add a band before the app knows it, and an
    /// unknown band is simply never offered.
    let moment: String?
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

/// The person a question is about, for the "Who he is" sheet under the answer.
/// Only the device-built packs (`live-squad`, `live-league`) set it; static
/// content ships none, so every field past the name is optional.
struct QuizPlayer: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let position: String
    let number: Int?
    let age: Int?
    let photoURL: String?
    let summary: String?
    let vibe: String?
    /// This club, this season (migration 100). Nil until the stats sync has
    /// run, and nil for every static-content question.
    var goals: Int? = nil
    var assists: Int? = nil
    var starts: Int? = nil
    var nationality: String? = nil
    /// The one sentence worth remembering him for, from `PlayerHooks`.
    var hook: String? = nil

    /// "5 goals · 2 assists · 4 starts", leaving out whatever is unknown.
    /// Nil when nothing has synced, so the sheet shows no empty row.
    var statsLine: String? {
        let bits = [goals.map { "\($0) \($0 == 1 ? "goal" : "goals")" },
                    assists.map { "\($0) \($0 == 1 ? "assist" : "assists")" },
                    starts.map { "\($0) \($0 == 1 ? "start" : "starts")" }].compactMap { $0 }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
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
    /// Who the question is about, when it is about a person.
    let player: QuizPlayer?

    init(id: String, difficulty: Int, verified: Bool = true, question: String, options: [String], answer: Int,
         explanation: String, why: String? = nil, use: String? = nil, useType: QuestionUseType? = nil,
         image: String? = nil, player: QuizPlayer? = nil) {
        self.id = id; self.difficulty = difficulty; self.verified = verified; self.question = question
        self.options = options; self.answer = answer; self.explanation = explanation
        self.why = why; self.use = use; self.useType = useType; self.image = image; self.player = player
    }
}
