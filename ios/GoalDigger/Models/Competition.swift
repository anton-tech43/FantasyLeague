import Foundation

/// The competitions the app covers, keyed by API-Football league id.
///
/// Mirrors `backend/supabase/functions/_shared/league-helpers.ts`. The numeric
/// id is the contract that travels on every surface — `content_items.league_id`,
/// `match_status_state.league_id`, the team page's `next_fixture` — so a card
/// never has to be guessed at from the club names in its headline.
///
/// House copy (2026-09-08): "League Cup (Carabao Cup)" in a sentence, plain
/// "League Cup" in a badge. Never "Carabao Cup" on its own.
enum Competition: Int, CaseIterable, Codable {
    case premierLeague = 39
    case championsLeague = 2
    case europaLeague = 3
    case conferenceLeague = 848
    case leagueCup = 48
    case faCup = 45
    case worldChampionship = 1

    /// The plain name.
    var name: String {
        switch self {
        case .premierLeague: return "Premier League"
        case .championsLeague: return "Champions League"
        case .europaLeague: return "Europa League"
        case .conferenceLeague: return "Conference League"
        case .leagueCup: return "League Cup"
        case .faCup: return "FA Cup"
        case .worldChampionship: return "World Championship"
        }
    }

    /// The name as it reads in a sentence, with the sponsor name where he uses it.
    var prose: String {
        self == .leagueCup ? "League Cup (Carabao Cup)" : name
    }

    /// Feed badge. Uppercased by the badge view, so this is the plain name.
    var badge: String { name }

    /// A knockout cup or a European competition — anything that is not the
    /// week-in, week-out league the feed already assumes.
    var isCup: Bool { self != .premierLeague && self != .worldChampionship }
}
