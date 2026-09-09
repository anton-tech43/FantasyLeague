import Foundation
import Observation

/// Two more quiz packs built on the device rather than shipped as JSON:
///
/// - **His squad** (`live-squad`) — every player at his club, from the
///   `players` table. Faces, shirt numbers and positions: the three things she
///   needs before a match makes any sense at all.
/// - **The league's big names** (`live-league`) — the other nineteen clubs'
///   ones-to-know, taken from the team-page slices `LiveClubPack` already
///   fetches for its distractors, so it costs no extra request.
///
/// Both reuse `LiveClubPack`'s question assembler, so option order is seeded
/// from the question id and stays put across launches while a round is paused.
/// Nil-safe throughout: no squad rows, or a row missing its number or photo,
/// means fewer questions, never a crash.
enum LiveSquadPack {
    static let packId = "live-squad"

    /// One row of `players`. Everything past the name is optional: the feed
    /// has no shirt number for some squad members, and no photo for others.
    struct Player: Codable, Hashable {
        let api_player_id: Int
        let name: String
        let position: String?
        let photo_url: String?
        let number: Int?
        /// This club, this season, all competitions (migration 095). Nil until
        /// the daily stats sync has run; 0 for a squad member yet to play.
        let appearances: Int?
        let minutes: Int?
        /// Set once per cache fill: api-sports answers 200 with a silhouette
        /// for a player it has no photo of. Absent from the feed, so it decodes
        /// as nil on the first fetch and is filled in before the pack is built.
        var photoIsPlaceholder: Bool? = nil

        /// Where he stands in the squad. Nil appearances is *unknown*, not
        /// zero: Saliba's stats had not synced, and "Is Saliba going to get a
        /// run this season?" is the wrong question about a first-choice
        /// centre-back. Unknown gets neither the fringe line nor the line that
        /// assumes everything goes through him.
        enum Standing { case fringe, regular, unknown }
        static func standing(appearances: Int?) -> Standing {
            guard let appearances else { return .unknown }
            return appearances == 0 ? .fringe : .regular
        }
        var standing: Standing { Self.standing(appearances: appearances) }
        var isFringe: Bool { standing == .fringe }

        /// A usable photo, or nil for the CDN silhouette.
        var photo: String? {
            guard photoIsPlaceholder != true, let p = photo_url, !p.isEmpty else { return nil }
            return p
        }
    }

    // MARK: His squad

    static func build(team: Team, players: [Player], cards: [PlayerCard],
                      personalise: (String) -> String) -> QuizPack? {
        let club = team.shortName
        let named = players.filter { !$0.name.isEmpty }
        #if DEBUG
        // Nil is unknown, not zero.
        assert(Player.standing(appearances: 0) == .fringe
            && Player.standing(appearances: 4) == .regular
            && Player.standing(appearances: nil) == .unknown)
        #endif

        // A surname is a name only when one man in the squad has it —
        // Bournemouth field R. and Z. Christie, and a question whose answer is
        // "Christie" is a question about neither of them. Where it is shared,
        // the feed's name is used whole; where the feed itself repeats a name
        // (Spurs list "T. Hall" twice) nothing we can print separates them, so
        // he is skipped entirely.
        var shortCounts: [String: Int] = [:], fullCounts: [String: Int] = [:]
        for p in named {
            shortCounts[LiveClubPack.shortName(p.name), default: 0] += 1
            fullCounts[p.name, default: 0] += 1
        }
        func display(_ p: Player) -> String {
            let s = LiveClubPack.shortName(p.name)
            return shortCounts[s] == 1 ? s : p.name
        }
        let allNames = named.filter { fullCounts[$0.name] == 1 }.map(display)
        var qs: [MyTurnQuestion] = []

        for p in named where fullCounts[p.name] == 1 {
            let short = display(p)
            let label = LiveClubPack.positionLabel(p.position ?? "")
            let card = match(p.name, in: cards)
            let summary = card.map { personalise($0.summary) }
            // API-Football carries stale numbers for some fringe players, so a
            // squad payload can show three men on 1. A number several men wear
            // is not a fact about any of them: it is left out of the
            // explanation and the player card as well as the question.
            let number = p.number.flatMap { n in named.filter { $0.number == n }.count == 1 ? n : nil }
            let person = QuizPlayer(name: short, position: label, number: number,
                                    age: card?.age, photoURL: p.photo,
                                    summary: summary, vibe: card?.vibe)
            let who = whoHeIs(short: short, club: club, label: label, number: number,
                              age: card?.age, summary: summary)

            // A photo is the only question that cannot be asked without one,
            // and a silhouette is not one: "Who is this?" over the grey figure
            // api-sports serves for a player it has no photo of is unanswerable.
            if let photo = p.photo {
                let sameShirt = named.filter { $0.position == p.position && $0.name != p.name && fullCounts[$0.name] == 1 }
                    .map(display)
                qs += LiveClubPack.question(
                    id: "squad-photo-\(p.api_player_id)", difficulty: p.isFringe ? 3 : 2,
                    question: "Who is this?",
                    answer: short,
                    distractors: sameShirt.count >= 3 ? sameShirt : allNames,
                    explanation: who,
                    why: p.isFringe
                        ? "One of the squad players. If he comes on late, you will be the one who knows the name."
                        : "Faces come before names. Once you know his, the commentary starts to make sense.",
                    useType: .say,
                    use: "When the camera finds him: " + LiveClubPack.quote("There's \(short)."),
                    image: photo, player: person
                )
            }

            if let n = number {
                qs += LiveClubPack.question(
                    id: "squad-number-\(p.api_player_id)", difficulty: 3,
                    question: "What number does \(short) wear?",
                    answer: "\(n)",
                    distractors: named.compactMap(\.number).filter { $0 != n }.map(String.init),
                    explanation: who,
                    why: "The shirt number is the quickest way to find one man among eleven.",
                    useType: .ask,
                    use: LiveClubPack.quote("Is that \(short), number \(n)?"),
                    player: person
                )
            }

            if p.position != nil {
                // "Everything goes through Dowman" is the right line for a man
                // who plays every week and a strange one for a sixteen-year-old
                // who has not. A fringe player gets the honest question; a man
                // whose stats have not synced gets neither line.
                let (why, useType, use): (String, QuestionUseType, String)
                switch p.standing {
                case .fringe:
                    why = "Squad players come and go from the bench. Knowing the name is enough."
                    useType = .ask
                    use = LiveClubPack.quote("Is \(short) going to get a run this season?")
                case .regular:
                    why = "He'll say the surname and expect you to know the job that comes with it."
                    useType = LiveClubPack.positionUseType(label)
                    use = LiveClubPack.positionUse(label, short: short)
                case .unknown:
                    why = "He'll say the surname and expect you to know the job that comes with it."
                    useType = .ask
                    use = LiveClubPack.quote("Is \(short) playing this weekend?")
                }
                qs += LiveClubPack.question(
                    id: "squad-pos-\(p.api_player_id)", difficulty: p.isFringe ? 3 : 1,
                    question: "What position does \(short) play?",
                    answer: label,
                    distractors: LiveClubPack.positionDistractors(for: label),
                    explanation: who,
                    why: why, useType: useType, use: use,
                    player: person
                )
            }
        }

        guard qs.count >= 4 else { return nil }
        return QuizPack(id: packId, label: "His squad", questions: qs)
    }

    /// With a dossier, the dossier is the sentence: the template only says the
    /// position again ("Saka plays as a forward for Arsenal. Saka is Arsenal's
    /// right-winger."). Without one, the template is all she gets, so it keeps
    /// the club and the role. Number and age are facts either way.
    private static func whoHeIs(short: String, club: String, label: String,
                                number: Int?, age: Int?, summary: String?) -> String {
        var s: String
        if let summary, !summary.isEmpty {
            s = LiveClubPack.clip(summary, 160)
            if let number { s += " Number \(number)." }
            if let age { s += " He's \(age)." }
            return s
        }
        let role = label == "Goalkeeper" ? "is \(club)'s goalkeeper" : "plays as a \(label.lowercased()) for \(club)"
        s = "\(short) \(role)"
        if let number { s += ", in the number \(number) shirt" }
        s += "."
        if let age { s += " He's \(age)." }
        return s
    }

    /// `players.name` comes abbreviated ("M. Ødegaard"); `player_cards` is
    /// written long ("Martin Ødegaard"). Prefer the whole name folded, and fall
    /// back to the surname only when one card carries it — Brentford have a
    /// Dango and a Demarai Ouattara, and the wrong dossier is worse than none.
    static func match(_ name: String, in cards: [PlayerCard]) -> PlayerCard? {
        let whole = fold(name)
        if !whole.isEmpty, let exact = cards.first(where: { fold($0.playerName) == whole }) { return exact }
        let key = surname(name)
        guard !key.isEmpty else { return nil }
        let hits = cards.filter { surname($0.playerName) == key }
        return hits.count == 1 ? hits[0] : nil
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                  locale: .init(identifier: "en")).lowercased()
    }

    private static func surname(_ name: String) -> String {
        fold(name).split(separator: " ").last.map(String.init) ?? ""
    }

    // MARK: The league's big names

    static let leaguePackId = "live-league"

    /// The other clubs' ones-to-know. `excluding` is his club, which has its
    /// own two packs already.
    static func buildLeague(slices: [LiveClubPack.Slice], excluding: String?,
                            personalise: (String) -> String) -> QuizPack? {
        let clubs = slices.filter { $0.team_id != excluding }
            .compactMap { s -> (String, [TopPlayer])? in
                guard let team = Team(rawValue: s.team_id), let ps = s.players, !ps.isEmpty else { return nil }
                return (team.shortName, ps)
            }
        let everyName = clubs.flatMap { $0.1 }.map { LiveClubPack.shortName($0.name) }
        let everyClub = clubs.map(\.0)
        var qs: [MyTurnQuestion] = []

        for (club, players) in clubs {
            for p in players {
                let short = LiveClubPack.shortName(p.name)
                let label = LiveClubPack.positionLabel(p.position)
                let liner = LiveClubPack.clip(personalise(p.oneLiner ?? ""), 150)
                let role = label == "Goalkeeper" ? "is \(club)'s goalkeeper" : "plays as a \(label.lowercased()) for \(club)"
                let who = liner.isEmpty ? "\(short) \(role)." : "\(short) \(role). \(liner)"
                let person = QuizPlayer(name: short, position: label, number: nil, age: nil,
                                        photoURL: p.photoURL, summary: liner.isEmpty ? nil : liner, vibe: nil)

                if let photo = p.photoURL, !photo.isEmpty {
                    qs += LiveClubPack.question(
                        id: "league-photo-" + LiveClubPack.slug(p.name), difficulty: 3,
                        question: "Who is this?",
                        answer: short, distractors: everyName,
                        explanation: who,
                        why: "He turns up on the highlights whoever is playing, so his face is worth knowing.",
                        useType: .say,
                        use: "When he appears on the screen: " + LiveClubPack.quote("That's \(short), isn't it?"),
                        image: photo, player: person
                    )
                }

                qs += LiveClubPack.question(
                    id: "league-club-" + LiveClubPack.slug(p.name), difficulty: 2,
                    question: "Which club does \(short) play for?",
                    answer: club, distractors: everyClub,
                    explanation: who,
                    why: "Twenty clubs is a lot. Knowing who plays where is most of the way there.",
                    useType: .ask,
                    use: LiveClubPack.quote("Are \(club) any good this season?"),
                    player: person
                )
            }
        }

        guard qs.count >= 10 else { return nil }
        return QuizPack(id: leaguePackId, label: "The league's big names", questions: qs)
    }
}

// MARK: - Service

/// Fetches his club's squad and dossiers and holds the built pack. One blob in
/// UserDefaults so the pack survives a launch with no signal.
@MainActor
@Observable
final class LiveSquadService {
    static let shared = LiveSquadService()

    private(set) var pack: QuizPack?

    private struct Cache: Codable {
        let teamId: String
        var players: [LiveSquadPack.Player]
        var cards: [PlayerCard]
        var fetchedAt: Date
        var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 24 * 60 * 60 }
    }

    private static let key = "myTurnSquad.v1"
    private var cache: Cache? {
        didSet {
            if let cache, let data = try? JSONEncoder().encode(cache) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key) {
            cache = try? JSONDecoder().decode(Cache.self, from: data)
        }
    }

    func clear() {
        pack = nil; cache = nil
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

    func refresh(team: Team?, personalise: @escaping (String) -> String) async {
        guard let team else { pack = nil; return }
        if cache?.teamId != team.rawValue { cache = nil }
        if cache == nil || cache!.isStale {
            // `select=*` rather than a column list: the squad table is still
            // growing columns, and naming one PostgREST does not have yet is a
            // 400 for the whole request. Forty narrow rows, so it is free.
            async let rows = APIClient.shared.rawGET(path: "players", queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "team_id", value: "eq.\(team.rawValue)"),
            ])
            async let dossiers = APIClient.shared.fetchPlayerCards(teamId: team.rawValue)
            let players = (try? await rows).flatMap {
                try? JSONDecoder().decode([LiveSquadPack.Player].self, from: $0)
            } ?? []
            if !players.isEmpty {
                cache = Cache(teamId: team.rawValue, players: await Self.flagPlaceholders(players),
                              cards: (try? await dossiers) ?? [], fetchedAt: Date())
            }
        }
        guard let cache else { pack = nil; return }
        pack = LiveSquadPack.build(team: team, players: cache.players, cards: cache.cards,
                                   personalise: personalise)
    }

    /// api-sports answers 200 with a grey silhouette for a player it has no
    /// photo of (four of Arsenal's squad on 2026-09-08), so the bytes are the
    /// only test. Thirty parallel 150x150 PNGs, once per cache fill — not once
    /// per launch — and the verdict is stored on the cached row.
    private static func flagPlaceholders(_ players: [LiveSquadPack.Player]) async -> [LiveSquadPack.Player] {
        await withTaskGroup(of: (Int, Bool).self) { group in
            for (i, p) in players.enumerated() {
                guard let s = p.photo_url, !s.isEmpty, let url = URL(string: s) else { continue }
                group.addTask {
                    let data = try? await URLSession.shared.data(from: url).0
                    return (i, data.map(LiveClubPack.isSilhouette) ?? false)
                }
            }
            var out = players
            for await (i, isPlaceholder) in group { out[i].photoIsPlaceholder = isPlaceholder }
            return out
        }
    }
}
