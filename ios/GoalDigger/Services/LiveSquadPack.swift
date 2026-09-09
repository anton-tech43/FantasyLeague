import Foundation
import Observation

/// Two more quiz packs built on the device rather than shipped as JSON:
///
/// - **His squad** (`live-squad`) — every player at his club, from the
///   `players` table. Faces, shirt numbers and positions: the three things she
///   needs before a match makes any sense at all.
/// - **The league's big names** (`live-league`) — two men from every other
///   club, picked from `players` so each one has a real face and a reason to
///   remember him. `LiveClubPackService` does the fetching; the picking and the
///   copy are here.
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
        /// Season columns from migration 100, all nullable and all "this club,
        /// this season, all competitions" except the two `league_*`, which are
        /// the Premier League only so "started every league game" can be checked
        /// against `standings.played`. Absent from the feed before the migration
        /// landed, so every one of them decodes as nil rather than throwing.
        var team_id: String? = nil
        var goals: Int? = nil
        var assists: Int? = nil
        var starts: Int? = nil
        var saves: Int? = nil
        var captain: Bool? = nil
        var nationality: String? = nil
        var age: Int? = nil
        var league_goals: Int? = nil
        var league_starts: Int? = nil
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

    /// - Parameters:
    ///   - played: the club's league games played, from the team page's
    ///     standings. Under three and no hook claims anything.
    ///   - manager: the manager card, for the one question in this pack that is
    ///     not about a player. It lives here rather than in `LiveClubPack`
    ///     because this pack is the people and that pack is the state of the
    ///     club.
    static func build(team: Team, players: [Player], cards: [PlayerCard], played: Int?,
                      manager: ManagerCard?, managerNames: [String], silhouettes: [String],
                      personalise: (String) -> String) -> QuizPack? {
        let club = team.shortName
        let named = players.filter { !$0.name.isEmpty }
        #if DEBUG
        // Nil is unknown, not zero.
        assert(Player.standing(appearances: 0) == .fringe
            && Player.standing(appearances: 4) == .regular
            && Player.standing(appearances: nil) == .unknown)
        assert(PlayerHooks.selfCheck(), "PlayerHooks copy table broke")
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
        let hooks = PlayerHooks.build(players: named, club: club, played: played, name: display)
        var qs: [MyTurnQuestion] = []

        // The manager: a person, so he belongs with the people. The name
        // question stays in `LiveClubPack`, where "who runs the club" is part of
        // the state of the club.
        if let m = manager, let photo = m.photoURL, !photo.isEmpty, !silhouettes.contains(photo) {
            qs += LiveClubPack.question(
                id: "squad-manager-photo", difficulty: 2,
                question: "Who is this?",
                answer: m.name, distractors: managerNames.filter { $0 != m.name },
                explanation: "\(m.name), \(club)'s manager. " + LiveClubPack.clip(personalise(m.summary), 120),
                why: "He's on screen every couple of minutes during a match, arms folded.",
                useType: .say,
                use: "Point at the screen: " + LiveClubPack.quote("That's \(m.name), isn't it?"),
                image: photo
            )
        }

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
            let hook = hooks[p.api_player_id]?.top
            let person = QuizPlayer(name: short, position: label, number: number,
                                    age: card?.age ?? p.age, photoURL: p.photo,
                                    summary: summary, vibe: card?.vibe,
                                    goals: p.goals, assists: p.assists, starts: p.starts,
                                    nationality: p.nationality, hook: hook?.fact)
            let who = whoHeIs(short: short, club: club, label: label, number: number,
                              age: card?.age ?? p.age, summary: summary, hook: hook?.fact)

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
                    // The bare "There's X" is the line for a man there is
                    // nothing else to say about, not the line for everybody.
                    useType: hook?.useType ?? .say,
                    use: hook?.use ?? ("When the camera finds him: " + LiveClubPack.quote("There's \(short).")),
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
                let (useType2, use2) = hook.map { ($0.useType, $0.use) } ?? (useType, use)
                qs += LiveClubPack.question(
                    id: "squad-pos-\(p.api_player_id)", difficulty: p.isFringe ? 3 : 1,
                    question: "What position does \(short) play?",
                    answer: label,
                    distractors: LiveClubPack.positionDistractors(for: label),
                    explanation: who,
                    why: why, useType: useType2, use: use2,
                    player: person
                )
            }
        }

        guard qs.count >= 4 else { return nil }
        return QuizPack(id: packId, label: "His squad", questions: qs)
    }

    /// Dossier first when there is one, then the hook as one sentence. With no
    /// dossier the hook leads and the template says what he does. With neither,
    /// the template is all she gets, so it keeps the club and the role.
    private static func whoHeIs(short: String, club: String, label: String,
                                number: Int?, age: Int?, summary: String?, hook: String?) -> String {
        var parts: [String] = []
        let hasSummary = !(summary ?? "").isEmpty
        if hasSummary { parts.append(LiveClubPack.clip(summary!, hook == nil ? 160 : 120)) }
        if let hook { parts.append(hook) }

        if parts.isEmpty {
            let role = label == "Goalkeeper" ? "is \(club)'s goalkeeper" : "plays as a \(label.lowercased()) for \(club)"
            parts.append("\(short) \(role)" + (number.map { ", in the number \($0) shirt" } ?? "") + ".")
        } else if !hasSummary {
            let role = label == "Goalkeeper" ? "He is \(club)'s goalkeeper" : "He plays as a \(label.lowercased()) for \(club)"
            parts.append(role + (number.map { ", number \($0)" } ?? "") + ".")
        } else if let number {
            parts.append("Number \(number).")
        }
        // The hook may already have said how old he is.
        if let age, !(hook ?? "").contains(" is \(age),") { parts.append("He's \(age).") }
        return parts.joined(separator: " ")
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

    /// Two real people per club, from `players` rather than the team page's
    /// prose, so everyone has a face and the question itself says why he is
    /// worth knowing. `excluding` is his club, which has its own two packs.
    ///
    /// - Parameters:
    ///   - picks: the selected rows, photos already verified (see
    ///     `LiveSquadService.flagPlaceholders`). Two per club, in no order.
    ///   - topScorers: per club, who leads the scoring and whether it is a tie.
    ///     A tie is never called "top scorer".
    ///   - liners: each club's `ones_to_know`, for the second sentence when the
    ///     name matches.
    static func buildLeague(picks: [Player], topScorers: [String: LiveClubPack.TopScorer],
                            liners: [String: [TopPlayer]], excluding: String?,
                            personalise: (String) -> String) -> QuizPack? {
        let named: [(club: String, teamId: String, player: Player)] = picks.compactMap { p in
            guard let teamId = p.team_id, teamId != excluding, let team = Team(rawValue: teamId),
                  !p.name.isEmpty else { return nil }
            return (team.shortName, teamId, p)
        }
        let everyClub = Set(named.map(\.club)).sorted()
        var qs: [MyTurnQuestion] = []

        for (club, teamId, p) in named {
            let short = LiveClubPack.shortName(p.name)
            let label = LiveClubPack.positionLabel(p.position ?? "")
            let leader = topScorers[teamId]
            let isTopScorer = leader.map { !$0.tied && $0.name == p.name } == true

            // The hook goes in the question itself: the club is the clue and
            // the face is the test, so naming the club gives nothing away.
            let hook: String?
            if isTopScorer, let g = leader?.goals, g > 0 {
                hook = p.appearances.map { "\(club)'s top scorer this season, \(g) in \($0) games." }
                    ?? "\(club)'s top scorer this season, \(g) so far."
            } else if let s = p.starts ?? p.appearances, s > 0 {
                hook = "He has started \(s) games for \(club) this season."
            } else {
                hook = nil
            }

            // A team-mate is never a distractor. She should be picking out a
            // face, not working out which of four men could be at that club.
            let awayNames = named.filter { $0.teamId != teamId }.map { LiveClubPack.shortName($0.player.name) }
            let liner = LiveClubPack.clip(personalise(oneLiner(p.name, in: liners[teamId] ?? []) ?? ""), 130)
            let role = label == "Goalkeeper" ? "is \(club)'s goalkeeper" : "plays as a \(label.lowercased()) for \(club)"
            let who = ["\(short) \(role).", hook, liner.isEmpty ? nil : liner]
                .compactMap { $0 }.joined(separator: " ")
            // The photo question already carries the hook in its text, so its
            // explanation does not say it a second time.
            let whoWithoutHook = ["\(short) \(role).", liner.isEmpty ? nil : liner]
                .compactMap { $0 }.joined(separator: " ")
            let person = QuizPlayer(name: short, position: label, number: p.number, age: p.age,
                                    photoURL: p.photo, summary: liner.isEmpty ? nil : liner, vibe: nil,
                                    goals: p.goals, assists: p.assists, starts: p.starts,
                                    nationality: p.nationality, hook: hook)

            if let photo = p.photo {
                qs += LiveClubPack.question(
                    id: "league-photo-\(p.api_player_id)", difficulty: 3,
                    question: hook.map { "Who is this? \($0)" } ?? "Who is this?",
                    answer: short, distractors: awayNames,
                    explanation: hook == nil ? who : whoWithoutHook,
                    why: "He turns up on the highlights whoever is playing, so his face is worth knowing.",
                    useType: .say,
                    use: "When he appears on the screen: " + LiveClubPack.quote("That's \(short), isn't it?"),
                    image: photo, player: person
                )
            }

            qs += LiveClubPack.question(
                id: "league-club-\(p.api_player_id)", difficulty: 2,
                question: "Which club does \(short) play for?",
                answer: club, distractors: everyClub.filter { $0 != club },
                explanation: who,
                why: "Twenty clubs is a lot. Knowing who plays where is most of the way there.",
                useType: .ask,
                use: LiveClubPack.quote("Are \(club) any good this season?"),
                player: person
            )
        }

        guard qs.count >= 10 else { return nil }
        return QuizPack(id: leaguePackId, label: "The league's big names", questions: qs)
    }

    /// The team page's one-liner for this man, when the page names him. Same
    /// rule as `match`: the whole folded name, or a surname only one of the
    /// page's players carries.
    private static func oneLiner(_ name: String, in players: [TopPlayer]) -> String? {
        let whole = fold(name)
        if let exact = players.first(where: { fold($0.name) == whole }) { return exact.oneLiner }
        let key = surname(name)
        guard !key.isEmpty else { return nil }
        let hits = players.filter { surname($0.name) == key }
        return hits.count == 1 ? hits[0].oneLiner : nil
    }

    /// Two per club: the top scorer (minutes break a tie), and the most-played
    /// player who is not already picked. In August, when nobody has scored,
    /// that is simply the two most-played. Photo-less men are never picked, so
    /// every face in the pack is a real face.
    static func leaguePicks(from rows: [Player]) -> [Player] {
        Dictionary(grouping: rows.compactMap { $0.team_id == nil ? nil : $0 }, by: { $0.team_id! })
            .values.flatMap { ps -> [Player] in
                let withPhoto = ps.filter { $0.photo != nil }
                let scorer = withPhoto.filter { ($0.goals ?? 0) > 0 }
                    .max { ($0.goals ?? 0, $0.minutes ?? 0) < ($1.goals ?? 0, $1.minutes ?? 0) }
                let played = withPhoto.filter { $0.api_player_id != scorer?.api_player_id }
                    .max { ($0.minutes ?? 0) < ($1.minutes ?? 0) }
                return [scorer, played].compactMap { $0 }
            }
    }

    /// The rows worth spending a photo check on: a few per club, so two survive
    /// when one of them turns out to be the CDN silhouette. Around eighty small
    /// PNGs once a day, not six hundred.
    static func leagueCandidates(from rows: [Player]) -> [Player] {
        Dictionary(grouping: rows.compactMap { $0.team_id == nil ? nil : $0 }, by: { $0.team_id! })
            .values.flatMap { ps -> [Player] in
                let scorers = ps.filter { ($0.goals ?? 0) > 0 && !($0.photo_url ?? "").isEmpty }
                    .sorted { ($0.goals ?? 0, $0.minutes ?? 0) > ($1.goals ?? 0, $1.minutes ?? 0) }.prefix(2)
                let played = ps.filter { !($0.photo_url ?? "").isEmpty }
                    .sorted { ($0.minutes ?? 0) > ($1.minutes ?? 0) }.prefix(3)
                var seen = Set<Int>()
                return (Array(scorers) + Array(played)).filter { seen.insert($0.api_player_id).inserted }
            }
    }

    /// Who leads the scoring at each club, and whether anyone is level with him.
    static func topScorers(from rows: [Player]) -> [String: LiveClubPack.TopScorer] {
        var out: [String: LiveClubPack.TopScorer] = [:]
        for (teamId, ps) in Dictionary(grouping: rows.compactMap { $0.team_id == nil ? nil : $0 }, by: { $0.team_id! }) {
            guard let best = ps.compactMap(\.goals).filter({ $0 > 0 }).max() else { continue }
            let level = ps.filter { $0.goals == best }
            guard let one = level.first else { continue }
            let rivals = ps.filter { $0.name != one.name && !$0.name.isEmpty }
                .sorted { ($0.minutes ?? 0) > ($1.minutes ?? 0) }.prefix(6).map(\.name)
            out[teamId] = LiveClubPack.TopScorer(team_id: teamId, name: one.name, goals: best,
                                                 tied: level.count > 1, rivals: Array(rivals))
        }
        return out
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
        /// Every PL manager's name, for the manager-photo question's three wrong
        /// answers. Twenty short strings; `LiveClubPackService` reads the same
        /// column, but the two services refresh independently and a shared
        /// singleton read would be a race on the first launch.
        var managerNames: [String] = []
        /// The manager photo, once its bytes have been checked (api-sports
        /// answers 200 with a silhouette). Empty means "real, or not checked".
        var silhouettes: [String] = []
        var fetchedAt: Date
        var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 24 * 60 * 60 }
    }

    private static let key = "myTurnSquad.v2"
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
        pack = nil; cache = nil; checkedManagerPhotos = []
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
            async let managers = APIClient.shared.rawGET(path: "teams", queryItems: [
                URLQueryItem(name: "select", value: "manager_name"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "league_id", value: "eq.39"),
            ])
            let players = (try? await rows).flatMap {
                try? JSONDecoder().decode([LiveSquadPack.Player].self, from: $0)
            } ?? []
            let names = (try? await managers).flatMap {
                try? JSONDecoder().decode([[String: String?]].self, from: $0)
            }?.compactMap { $0["manager_name"] ?? nil } ?? []
            if !players.isEmpty {
                cache = Cache(teamId: team.rawValue, players: await Self.flagPlaceholders(players),
                              cards: (try? await dossiers) ?? [], managerNames: names, fetchedAt: Date())
            }
        }
        guard var cache else { pack = nil; return }

        // The manager card and the club's games played both live on the team
        // page, which His Team already caches. Fetch it only when it is missing.
        var page = TeamPageCache.load(teamId: team.rawValue)
        if page == nil || page!.isStale, let fresh = try? await APIClient.shared.fetchTeamPage(teamId: team.rawValue) {
            TeamPageCache.save(content: fresh, teamId: team.rawValue)
            page = TeamPageCache.load(teamId: team.rawValue)
        }
        let cards = page?.content.cards
        let played = cards?.standings?.entries
            .first { $0.teamIdApiFootball == team.apiFootballId || $0.teamName == team.displayName }?.played

        // The manager's photo is the one image in this pack we have not already
        // hashed. Check it once per cache fill, like the players'.
        if let photo = cards?.manager?.photoURL, !photo.isEmpty, !cache.silhouettes.contains(photo),
           !checkedManagerPhotos.contains(photo), let url = URL(string: photo) {
            checkedManagerPhotos.insert(photo)
            if let data = try? await URLSession.shared.data(from: url).0, LiveClubPack.isSilhouette(data) {
                cache.silhouettes.append(photo)
                self.cache = cache
            }
        }

        pack = LiveSquadPack.build(team: team, players: cache.players, cards: cache.cards, played: played,
                                   manager: cards?.manager, managerNames: cache.managerNames,
                                   silhouettes: cache.silhouettes, personalise: personalise)
    }

    private var checkedManagerPhotos: Set<String> = []

    /// api-sports answers 200 with a grey silhouette for a player it has no
    /// photo of (four of Arsenal's squad on 2026-09-08), so the bytes are the
    /// only test. Thirty parallel 150x150 PNGs, once per cache fill — not once
    /// per launch — and the verdict is stored on the cached row.
    static func flagPlaceholders(_ players: [LiveSquadPack.Player]) async -> [LiveSquadPack.Player] {
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
