import Foundation

/// A 3-question Saturday morning quiz about her team's weekend fixture.
/// Generated weekly by the gd-saturday-quiz cloud routine (cron 0 7 * * 6,
/// Saturday 07:00 UTC). One row per team per week. iOS reads the freshest
/// row via the quiz-current Edge Function which gates on a 36-hour window
/// so the card only appears Saturday/Sunday. T3+ tier-gated client-side.
///
/// V1.1 task C3.
struct SaturdayQuiz: Codable, Identifiable, Equatable {
    let id: UUID
    let teamId: String
    /// Optional API-Football fixture id for the weekend's match. Nullable
    /// because the routine may run before fixtures are confirmed, or for a
    /// team with no PL fixture this weekend.
    let matchId: String?
    /// Short label shown on the collapsed pill, e.g. "Liverpool weekend".
    let headline: String
    /// Always 3 questions (validated server-side).
    let questions: [QuizQuestion]
    /// Template the iOS ShareLink fills in with the user's score.
    /// Contains literal `{score}` placeholder we substitute at share time.
    /// Example: "GoalDigger Saturday Quiz: {score}/3 — Arsenal weekend"
    let shareTemplate: String
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, headline, questions
        case teamId = "team_id"
        case matchId = "match_id"
        case shareTemplate = "share_template"
        case publishedAt = "published_at"
    }
}

/// One quiz question. `id` is generated locally on decode so SwiftUI's
/// ForEach has a stable identity per question without the backend having
/// to assign one (questions are inline in a JSONB array on the row).
struct QuizQuestion: Codable, Identifiable, Equatable {
    /// Locally generated; not part of the wire format. ForEach key.
    let id: UUID
    let q: String
    /// Exactly 3 options (validated server-side by post_quiz.sh).
    let options: [String]
    /// Index into `options` — 0, 1, or 2.
    let correct: Int
    /// Sister-voice statement revealed after she picks an option. No '?'
    /// or '!' — those are stripped by the post script.
    let explainer: String

    enum CodingKeys: String, CodingKey {
        case q, options, correct, explainer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Generate id locally — it isn't on the wire. Each decode produces
        // a fresh UUID; ForEach keys stay stable for the lifetime of the
        // SaturdayQuiz value because the same array is reused.
        self.id = UUID()
        self.q = try container.decode(String.self, forKey: .q)
        self.options = try container.decode([String].self, forKey: .options)
        self.correct = try container.decode(Int.self, forKey: .correct)
        self.explainer = try container.decode(String.self, forKey: .explainer)
    }

    /// Memberwise init for previews and tests. Not used by JSON decode.
    init(id: UUID = UUID(), q: String, options: [String], correct: Int, explainer: String) {
        self.id = id
        self.q = q
        self.options = options
        self.correct = correct
        self.explainer = explainer
    }
}
