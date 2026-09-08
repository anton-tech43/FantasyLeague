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
    }

    // MARK: His squad

    static func build(team: Team, players: [Player], cards: [PlayerCard],
                      personalise: (String) -> String) -> QuizPack? {
        let club = team.shortName
        let named = players.filter { !$0.name.isEmpty }
        let allNames = named.map { LiveClubPack.shortName($0.name) }
        var qs: [MyTurnQuestion] = []

        for p in named {
            let short = LiveClubPack.shortName(p.name)
            let label = LiveClubPack.positionLabel(p.position ?? "")
            let card = match(short, in: cards)
            let person = QuizPlayer(name: short, position: label, number: p.number,
                                    age: card?.age, photoURL: p.photo_url,
                                    summary: card.map { personalise($0.summary) }, vibe: card?.vibe)
            let who = whoHeIs(short: short, club: club, label: label, number: p.number,
                              age: card?.age, summary: card.map { personalise($0.summary) })

            // A photo is the only question that cannot be asked without one.
            // The rare CDN silhouette gets through: checking the bytes would be
            // one request per player, and there are forty of them.
            // ponytail: accepts a silhouette rather than 40 HEADs. Upgrade path
            // is the backfill nulling photo_url for placeholder checksums.
            if let photo = p.photo_url, !photo.isEmpty {
                let sameShirt = named.filter { $0.position == p.position && $0.name != p.name }
                    .map { LiveClubPack.shortName($0.name) }
                qs += LiveClubPack.question(
                    id: "squad-photo-\(p.api_player_id)", difficulty: 2,
                    question: "Who is this?",
                    answer: short,
                    distractors: sameShirt.count >= 3 ? sameShirt : allNames,
                    explanation: who,
                    why: "Faces come before names. Once you know his, the commentary starts to make sense.",
                    useType: .say,
                    use: "When the camera finds him: " + LiveClubPack.quote("There's \(short)."),
                    image: photo, player: person
                )
            }

            if let n = p.number {
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
                qs += LiveClubPack.question(
                    id: "squad-pos-\(p.api_player_id)", difficulty: 1,
                    question: "What position does \(short) play?",
                    answer: label,
                    distractors: LiveClubPack.positionDistractors(for: label),
                    explanation: who,
                    why: "He'll say the surname and expect you to know the job that comes with it.",
                    useType: LiveClubPack.positionUseType(label),
                    use: LiveClubPack.positionUse(label, short: short),
                    player: person
                )
            }
        }

        guard qs.count >= 4 else { return nil }
        return QuizPack(id: packId, label: "His squad", questions: qs)
    }

    /// "Ødegaard plays as a midfielder for Arsenal, in the number 8 shirt.
    /// He's 27. <dossier>" — facts first, so a player with no dossier still
    /// gets a real answer.
    private static func whoHeIs(short: String, club: String, label: String,
                                number: Int?, age: Int?, summary: String?) -> String {
        let role = label == "Goalkeeper" ? "is \(club)'s goalkeeper" : "plays as a \(label.lowercased()) for \(club)"
        var s = "\(short) \(role)"
        if let number { s += ", in the number \(number) shirt" }
        s += "."
        if let age { s += " He's \(age)." }
        if let summary, !summary.isEmpty { s += " " + LiveClubPack.clip(summary, 160) }
        return s
    }

    /// `players.name` comes abbreviated ("M. Ødegaard"); `player_cards` is
    /// written long ("Martin Ødegaard"). Match on the surname, folded, per
    /// DATA_SOURCES.md.
    static func match(_ short: String, in cards: [PlayerCard]) -> PlayerCard? {
        let key = surname(short)
        guard !key.isEmpty else { return nil }
        return cards.first { surname($0.playerName) == key }
    }

    private static func surname(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                 locale: .init(identifier: "en")).lowercased()
        return folded.split(separator: " ").last.map(String.init) ?? ""
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
                cache = Cache(teamId: team.rawValue, players: players,
                              cards: (try? await dossiers) ?? [], fetchedAt: Date())
            }
        }
        guard let cache else { pack = nil; return }
        pack = LiveSquadPack.build(team: team, players: cache.players, cards: cache.cards,
                                   personalise: personalise)
    }
}
