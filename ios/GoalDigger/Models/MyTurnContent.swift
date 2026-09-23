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
    /// Called it (2026-09-23): the lines she can put on a slip before kick-off.
    /// Optional because the key is being added to lingo.json separately — a
    /// build that decodes a file without it simply has no slip to offer.
    let calls: [LingoCall]?
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
    /// older cached file still decodes. `var` for the same reason `overheard`
    /// is: `naming(_:_:)` rewrites it with a real player's name.
    var sayIt: String?
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
    /// `var` only so `naming(_:_:)` can hand back a copy carrying a real
    /// player's name; nothing else writes it.
    var overheard: String?
    /// The exact substring of `overheard` to bold, emitted by the build script
    /// so the view can bold with a plain `range(of:)` and no matching rules.
    var overheardTerm: String?
    let speaker: LingoSpeaker?
    /// The right answer: what he meant, in her words.
    let gist: String?
    /// The one hand-written wrong answer she is shown, same length band as
    /// `gist`. Authored rather than computed: a runtime pick out of a pair
    /// would re-seed per session and could never be validated, and a length
    /// heuristic would move the shipped card whenever a gist is trimmed. The
    /// second wrong answer is written and reviewed but stays in the source as
    /// `spare`, so reverting to three options is a one-line change and not a
    /// writing job.
    let decoy: String?
    /// The reviewed wrong answer that does not ship. Never shown, never an
    /// option, decoded only so `lingoDeckSelfCheck` can prove that every word
    /// in the bundle still has one — a revert nobody can evidence is not a
    /// revert. A cached file published before the rename has none, which is
    /// why it is optional like the rest.
    let spare: String?
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

    // MARK: Player variants (2026-09-23)

    /// A rewrite of this term's three text fields that names a real player
    /// from the actual fixture, resolved on the phone by `PlayerSlots`.
    ///
    /// It overrides an existing term rather than minting a card id: her
    /// known/learning progress is keyed on term ids, so a one-off id would be
    /// progress she could never bank. `speaker`, `gist`, `decoy`, `when`,
    /// `basic` and `moment` are inherited and never overridden — a decoy is a
    /// *wrong* meaning, so a name in one would assert something false about a
    /// real person, and a proper noun in one option out of two is the whole
    /// card given away.
    struct PlayerVariant: Codable, Hashable {
        /// `{ours|theirs}.{keeper|defender|midfielder|forward}`. A `String`
        /// rather than an enum for the same reason `when` is `[String]`: a
        /// publish may add a slot before the app knows it, and an unknown slot
        /// simply never resolves, which leaves the plain line on screen.
        let slot: String
        /// The line as it would be said, with `{slot}` where the name goes.
        let overheard: String
        /// The substring of `overheard` to bold, emitted per variant by the
        /// build script. Nil falls back to the term's own.
        let overheardTerm: String?
        /// The line she says back, with `{slot}` where the name goes.
        let sayIt: String
    }

    /// Nil on every term until the content build starts emitting them, and nil
    /// forever on a cached file published before they existed.
    let playerVariants: [PlayerVariant]?

    /// This term with `variant`'s lines in place of its own and the slot token
    /// replaced by `named`.
    ///
    /// The one place the substitution happens, so the bubble, the reveal and
    /// the line the round leaves her with can never disagree about what he
    /// was called.
    func naming(_ named: String, _ variant: PlayerVariant) -> LingoTerm {
        let token = "{\(variant.slot)}"
        var copy = self
        copy.overheard = variant.overheard.replacingOccurrences(of: token, with: named)
        copy.overheardTerm = variant.overheardTerm ?? overheardTerm
        copy.sayIt = variant.sayIt.replacingOccurrences(of: token, with: named)
        return copy
    }
}

// MARK: Called it (2026-09-23)
//
// Three lines before kick-off: one near-certain, one likely, one long shot.
// She picks them and watches for her moment. The app never asks whether she
// said it — it knows what happened on the pitch, and that is the whole game.
//
// The grammar is fixed by tools/myturn/CALLED_IT_CONTRACT.md and its semantics
// by tools/myturn/call_vectors.json, which `LingoCalls.selfCheck` and the Deno
// resolver's test both read. Neither side may add a case without the other
// going red.

/// The moment that earns a line. Every field optional and meaning "don't care"
/// when absent, exactly as `_shared/match-calls.ts` reads it: a trigger field
/// that IS present is never satisfied by an unknown outcome field.
///
/// Camel-case keys, unlike the snake_case the rest of the content files use:
/// the same JSON travels to the server verbatim inside a stored pick, and the
/// contract and the vectors spell it this way.
/// `var` throughout only so the memberwise initialiser defaults every field to
/// nil, which is what "absent means don't care" looks like at a call site.
struct LingoCallTrigger: Codable, Hashable {
    /// `goal | halftime | fulltime`. A kind this build does not know never
    /// resolves, which is what keeps a newer content file safe here.
    var kind: String?
    /// `us | them | any`, relative to the club she follows.
    var side: String?
    /// `Goalkeeper | Defender | Midfielder | Attacker | any` — the four values
    /// `players.position` actually holds, per `PlayerSlots`.
    var scorerRole: String?
    var penalty: Bool?
    var ownGoal: Bool?
    var minuteFrom: Int?
    var minuteTo: Int?
    /// `ahead|level|behind` at half-time, `win|draw|loss` at full-time.
    var state: String?
    var conceded: Int?
    var cleanSheet: Bool?
    var comeback: Bool?
}

/// One line on the slip.
///
/// Every field decoded with `decodeIfPresent`: a call this build cannot use is
/// dropped by `LingoCalls.offer` rather than throwing, because one malformed
/// element would otherwise take the whole `LingoContent` decode down with it
/// and leave the module on the bundled file.
struct LingoCall: Codable, Identifiable, Hashable {
    let id: String
    let line: String
    let trigger: LingoCallTrigger?
    /// `banker | likely | longshot`. A band this build does not know is never
    /// offered — same rule as `LingoTerm.moment`.
    let band: String?
    /// Overheard tag vocabulary, unchanged, so a slip is fixture-aware for
    /// free. Nil means "any match".
    let when: [String]?
    /// The Lingo term this line came out of, when there is one: the words she
    /// learned are the words she gets to use.
    let termId: String?
    /// When she gets to say it, hand-written: "If their striker gets one from
    /// the spot". Nil falls back to `LingoCalls.moment(trigger:)`, which reads
    /// the trigger itself, so every line has a when from day one — the authored
    /// field exists because a derivation cannot say what the grammar does not
    /// hold. Only `line` keeps the 50-character cap, because only `line` enters
    /// the push body.
    let situation: String?
    /// Why it is worth calling — the half-sentence that turns a moment into a
    /// bet. Nil simply draws nothing.
    let cue: String?

    init(id: String, line: String, trigger: LingoCallTrigger?, band: String?,
         when: [String]? = nil, termId: String? = nil,
         situation: String? = nil, cue: String? = nil) {
        self.id = id; self.line = line; self.trigger = trigger
        self.band = band; self.when = when; self.termId = termId
        self.situation = situation; self.cue = cue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        line = try c.decodeIfPresent(String.self, forKey: .line) ?? ""
        trigger = try c.decodeIfPresent(LingoCallTrigger.self, forKey: .trigger)
        band = try c.decodeIfPresent(String.self, forKey: .band)
        when = try c.decodeIfPresent([String].self, forKey: .when)
        termId = try c.decodeIfPresent(String.self, forKey: .termId)
        situation = try c.decodeIfPresent(String.self, forKey: .situation)
        cue = try c.decodeIfPresent(String.self, forKey: .cue)
    }
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
