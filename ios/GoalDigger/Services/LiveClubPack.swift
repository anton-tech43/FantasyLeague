import CryptoKit
import Foundation
import Observation

/// "His club, right now" — the one quiz pack that is built on the device from
/// live data instead of shipped as JSON.
///
/// Static content must never name a current manager or squad member (the first
/// batch called 2006 Arsenal's *only* Champions League final; they played the
/// 2026 one). The present comes from `team_pages` — manager, ones to know,
/// the basics glance, the rival — and from `teams.manager_name`, which is the
/// human-verified source for who manages a club (DATA_SOURCES.md). When the
/// team page routine updates, the pack updates. CONTENT_PRINCIPLES.md §4.
///
/// Pure builder + small fetch/cache service. The builder is deterministic for
/// a given input (option order is seeded from the question id) so the pack is
/// the same on every launch until the data changes, and a round in progress
/// still finds its questions.
enum LiveClubPack {
    static let packId = "live-club"

    // MARK: Sources

    /// The slice of every PL club's team page the pack needs for distractors.
    /// Fetched in one PostgREST request with JSON-path selects (~38 KB).
    struct Slice: Codable {
        let team_id: String
        let manager: ManagerCard?
        let players: [TopPlayer]?
        let basics: BasicsCard?
        let rival: String?
    }

    struct ClubManager: Codable {
        let id: String
        let display_name: String
        let short_name: String
        let manager_name: String?
    }

    struct Sources: Codable {
        var managers: [ClubManager]
        var slices: [Slice]
        var fetchedAt: Date
        /// Photo URLs verified as CDN silhouettes; a "Who is this?" on one of
        /// these would be a photo of nobody.
        var silhouettes: [String] = []

        var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 24 * 60 * 60 }
    }

    /// api-sports returns HTTP 200 with a silhouette for a missing photo, so
    /// the only test is the bytes. Two coach variants seen on 2026-09-08 (7 of
    /// 20 PL managers), the "unknown id" image, and the player silhouette
    /// (2026-09-09: four of Arsenal's squad).
    // ponytail: hash list, not a classifier. Extend when a new silhouette shows
    // up (compare md5 of a known-bad URL) — or move the check server-side into
    // the team-page routine so photo_url is null for placeholders.
    static let silhouetteMD5: Set<String> = [
        "3e52d4ec4bb65b0a2019236c4dabd3fc",
        "f512b984f93ca6915dd623351b93b531",
        "0e3bde19a08632f2e893bc2a835598bc",
        "430d67fd79ad0a355b212d5780886e34",
    ]

    static func isSilhouette(_ data: Data) -> Bool {
        let digest = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return silhouetteMD5.contains(digest)
    }

    // MARK: Build

    /// Builds the pack for `team` from its page and the league-wide sources.
    /// Returns nil when there is not enough to ask even one question.
    /// `personalise` resolves `[his name]` in text lifted from the team page.
    static func build(team: Team, page: TeamPageContent, sources: Sources,
                      personalise: (String) -> String) -> QuizPack? {
        let cards = page.cards
        let club = team.shortName
        let others = sources.slices.filter { $0.team_id != team.rawValue }
        var qs: [MyTurnQuestion] = []

        // Manager — name from the page (written from teams.manager_name by the
        // routine), distractors from the verified column.
        if let m = cards.manager {
            let rivalsManagers = sources.managers
                .filter { $0.id != team.rawValue }
                .compactMap(\.manager_name)
                .filter { $0 != m.name }
            let summary = clip(personalise(m.summary), 150)
            let tp = m.talkingPoint.map(personalise)
            qs += question(
                id: "live-manager-name", difficulty: 1,
                question: "Who manages \(club)?",
                answer: m.name, distractors: rivalsManagers,
                explanation: summary,
                why: "The manager is the one he'll praise or blame after every single match.",
                useType: tp == nil ? .ask : .say,
                use: tp.map { quote($0) } ?? quote("Is \(m.name) under pressure yet?")
            )
            if let photo = m.photoURL, !sources.silhouettes.contains(photo) {
                qs += question(
                    id: "live-manager-photo", difficulty: 2,
                    question: "Who is this?",
                    answer: m.name, distractors: rivalsManagers,
                    explanation: "\(m.name), \(club)'s manager. \(clip(personalise(m.summary), 120))",
                    why: "He's on screen every couple of minutes during a match, arms folded.",
                    useType: .say,
                    use: "Point at the screen: " + quote("That's \(m.name), isn't it?"),
                    image: photo
                )
            }
        }

        // Ones to know — position, face, and which club.
        let players = cards.onesToKnow?.players ?? []
        let awayPlayers = others.flatMap { $0.players ?? [] }.map(\.name)
        for p in players {
            let label = positionLabel(p.position)
            let short = shortName(p.name)
            let liner = clip(personalise(p.oneLiner ?? ""), 150)
            let role = label == "Goalkeeper" ? "is the goalkeeper" : "plays as a \(label.lowercased())"
            qs += question(
                id: "live-pos-" + slug(p.name), difficulty: 1,
                question: "What position does \(p.name) play?",
                answer: label, distractors: positionDistractors(for: label),
                explanation: liner.isEmpty ? "\(short) \(role) for \(club)." : "\(short) \(role). \(liner)",
                why: "He'll say \"\(short)\" and nothing else, and expect you to know the job.",
                useType: positionUseType(label),
                use: positionUse(label, short: short)
            )
            if let photo = p.photoURL, !sources.silhouettes.contains(photo) {
                let names = players.map(\.name).filter { $0 != p.name } + awayPlayers
                qs += question(
                    id: "live-photo-" + slug(p.name), difficulty: 2,
                    question: "Who is this?",
                    answer: p.name, distractors: names,
                    explanation: "\(p.name), \(club)'s \(label.lowercased()). \(liner)",
                    why: "Faces are how you follow a match. The names come after.",
                    useType: .say,
                    use: "Casually, when the camera finds him: " + quote("There's \(short)."),
                    image: photo
                )
            }
        }
        if let p = players.first, awayPlayers.count >= 3 {
            let short = shortName(p.name)
            qs += question(
                id: "live-plays-for", difficulty: 2,
                question: "Which of these plays for \(club)?",
                answer: p.name, distractors: awayPlayers,
                explanation: clip(personalise(p.oneLiner ?? "\(p.name) is one of \(club)'s key players."), 170),
                why: "Knowing one name is the difference between watching and following.",
                useType: .ask,
                use: quote("Is \(short) fit for the weekend?")
            )
        }

        // The basics glance — last season, last title, nickname, ground.
        if let b = cards.basics {
            let otherBasics = others.compactMap(\.basics)
            if let last = b.lastSeason {
                qs += question(
                    id: "live-last-season", difficulty: 2,
                    question: "How did \(club) do last season?",
                    answer: last, distractors: otherBasics.compactMap(\.lastSeason),
                    explanation: [last, b.plSince].compactMap { $0 }.joined(separator: ". ") + ".",
                    why: "Last season is the yardstick for everything he says about this one.",
                    useType: .ask,
                    use: quote("Better or worse than last season so far?")
                )
            }
            if let title = b.lastTitle {
                let never = title.lowercased() == "never"
                let reigning = title.lowercased().contains("last season")
                let year = title.split(separator: ",").first.map(String.init) ?? title
                let use: (QuestionUseType, String) = never
                    ? (.ask, quote("Have \(club) ever come close to winning it?"))
                    : reigning
                        ? (.say, quote("Reigning champions. No pressure, then."))
                        : (.impress, quote("\(club) haven't won the league since \(year), have they?"))
                qs += question(
                    id: "live-last-title", difficulty: 3,
                    question: "When did \(club) last win the league?",
                    answer: title, distractors: otherBasics.compactMap(\.lastTitle),
                    explanation: never
                        ? "\(club) have not won the top-flight title. \(b.nickname) fans know exactly how long the wait is."
                        : "\(club) were champions in \(year). " + (b.lastSeason.map { "Last season: \($0)." } ?? ""),
                    why: "It's the first thing a rival fan brings up, so he has an answer ready.",
                    useType: use.0, use: use.1
                )
            }
            let nick = cleanNickname(b.nickname)
            qs += question(
                id: "live-nickname", difficulty: 1,
                question: "What are \(club) known as?",
                answer: b.nickname, distractors: otherBasics.map(\.nickname),
                explanation: "\(club) are \(b.nickname). Commentators and fans use it without thinking, so he will too.",
                why: "Half the time he won't say the club's name at all.",
                useType: .say,
                use: quote("Come on you \(nick)!")
            )
            if let ground = b.stadium {
                let short = stadiumShort(ground)
                qs += question(
                    id: "live-stadium", difficulty: 1,
                    question: "Where do \(club) play their home games?",
                    answer: short, distractors: otherBasics.compactMap(\.stadium).map(stadiumShort),
                    explanation: "\(ground). When he says \"we're at home\", this is where he means.",
                    why: "Home or away is the first thing he'll say about any fixture.",
                    useType: .ask,
                    use: quote("Have you ever been to \(short)?")
                )
            }
        }

        // The rival.
        if let r = cards.rivalry, let rival = r.rival {
            let rivalShort = Team.allCases.first { $0.displayName == rival }?.shortName ?? rival
            qs += question(
                id: "live-rival", difficulty: 2,
                question: "Who are \(club)'s big rivals?",
                answer: rival,
                distractors: others.compactMap(\.rival).filter { $0 != team.displayName && $0 != team.shortName },
                explanation: clip(personalise(r.text), 170),
                why: "The derby is the one match he'll be unbearable about, win or lose.",
                useType: .say,
                use: quote("Forget the table. Just beat \(rivalShort).")
            )
        }

        guard qs.count >= 4 else { return nil }
        return QuizPack(id: packId, label: "His club, right now", questions: qs)
    }

    // MARK: Question assembly

    /// One question, or nothing if fewer than three distinct distractors exist.
    /// Options are shuffled with a generator seeded from the id so the order is
    /// stable across launches and re-renders. Shared with `LiveSquadPack`.
    static func question(id: String, difficulty: Int, question: String, answer: String,
                         distractors: [String], explanation: String, why: String,
                         useType: QuestionUseType, use: String, image: String? = nil,
                         player: QuizPlayer? = nil) -> [MyTurnQuestion] {
        var seen: Set<String> = [answer.lowercased()]
        var picks: [String] = []
        var rng = SeededGenerator(seed: id)
        for d in distractors.shuffled(using: &rng) where d.count <= 40 && !seen.contains(d.lowercased()) {
            seen.insert(d.lowercased()); picks.append(d)
            if picks.count == 3 { break }
        }
        guard picks.count == 3, answer.count <= 40 else { return [] }
        var options = picks + [answer]
        options.shuffle(using: &rng)
        return [MyTurnQuestion(id: id, difficulty: difficulty, question: question, options: options,
                               answer: options.firstIndex(of: answer)!, explanation: explanation,
                               why: why, use: use, useType: useType, image: image, player: player)]
    }

    // MARK: Text helpers

    static func quote(_ s: String) -> String { "\u{201C}\(s)\u{201D}" }

    /// Cut at a sentence end under the cap; else at a word, with an ellipsis.
    static func clip(_ text: String, _ cap: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > cap else { return t }
        let head = String(t.prefix(cap))
        if let end = head.lastIndex(where: { ".!?".contains($0) }), head.distance(from: head.startIndex, to: end) > cap / 3 {
            return String(head[...end])
        }
        if let space = head.lastIndex(of: " ") {
            return String(head[..<space]).trimmingCharacters(in: .punctuationCharacters) + "…"
        }
        return head + "…"
    }

    /// "M. Ødegaard" → "Ødegaard"; "E. Smith Rowe" → "Smith Rowe";
    /// "Bruno Fernandes" and "Evanilson" stay as they are.
    static func shortName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2, parts[0].count == 2, parts[0].hasSuffix(".") {
            return parts.dropFirst().joined(separator: " ")
        }
        return name
    }

    static func slug(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en"))
        let kept = folded.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        return kept.split(separator: "-").joined(separator: "-")
    }

    static func positionLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "goalkeeper": return "Goalkeeper"
        case "defender": return "Defender"
        case "midfielder": return "Midfielder"
        case "winger": return "Winger"
        case "striker": return "Striker"
        case "attacker", "forward": return "Forward"
        default: return raw.capitalized
        }
    }

    /// Never offer two attacking labels together — "Striker" against "Forward"
    /// is a trick question, not a quiz question.
    static func positionDistractors(for label: String) -> [String] {
        switch label {
        case "Midfielder": return ["Goalkeeper", "Defender", "Striker"]
        case "Defender":   return ["Goalkeeper", "Midfielder", "Striker"]
        case "Goalkeeper": return ["Defender", "Midfielder", "Striker"]
        default:           return ["Goalkeeper", "Defender", "Midfielder"]
        }
    }

    static func positionUseType(_ label: String) -> QuestionUseType {
        label == "Defender" ? .ask : .say
    }

    static func positionUse(_ label: String, short: String) -> String {
        switch label {
        case "Goalkeeper": return "When one goes in: " + quote("Nothing \(short) could do about that.")
        case "Defender":   return quote("Is \(short) the one organising the back line?")
        case "Midfielder": return quote("Everything goes through \(short).")
        default:           return quote("Get it to \(short).")
        }
    }

    /// "The Gunners" → "Gunners"; "Spurs (or Lilywhites)" → "Spurs".
    static func cleanNickname(_ n: String) -> String {
        var s = n
        if let p = s.firstIndex(of: "(") { s = String(s[..<p]) }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix("the ") { s = String(s.dropFirst(4)) }
        return s
    }

    /// "Emirates Stadium, London" → "Emirates Stadium".
    static func stadiumShort(_ s: String) -> String {
        s.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? s
    }

    /// SplitMix64 seeded from a string hash. Foundation's `hashValue` is
    /// per-process randomised, so it cannot be the seed.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: String) {
            var h: UInt64 = 0xcbf29ce484222325
            for b in seed.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            state = h
        }
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
}

// MARK: - Service

/// Holds the built pack for the selected club and the cached league-wide
/// sources. `refresh` is cheap when everything is cached, so the tab calls it
/// on appear and whenever the selected team changes.
@MainActor
@Observable
final class LiveClubPackService {
    static let shared = LiveClubPackService()

    private(set) var pack: QuizPack?
    /// "The league's big names" — the other clubs' ones-to-know, built from the
    /// same slices the pack above uses for distractors, so it costs no request.
    private(set) var leaguePack: QuizPack?
    private(set) var teamId: String?

    private static let sourcesKey = "myTurnLiveSources.v1"
    private var sources: LiveClubPack.Sources? {
        didSet {
            if let sources, let data = try? JSONEncoder().encode(sources) {
                UserDefaults.standard.set(data, forKey: Self.sourcesKey)
            }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.sourcesKey) {
            sources = try? JSONDecoder().decode(LiveClubPack.Sources.self, from: data)
        }
    }

    func clear() {
        pack = nil; leaguePack = nil; teamId = nil; sources = nil
        UserDefaults.standard.removeObject(forKey: Self.sourcesKey)
    }

    func refresh(team: Team?, personalise: @escaping (String) -> String) async {
        teamId = team?.rawValue
        if team == nil { pack = nil }

        // League-wide sources, at most once a day. They also carry the league
        // pack, which is worth having whether or not she follows a club.
        if sources == nil || sources!.isStale {
            if let fresh = try? await Self.fetchSources() {
                var merged = fresh
                merged.silhouettes = sources?.silhouettes ?? []
                sources = merged
            }
        }
        guard var src = sources else { return }
        leaguePack = LiveSquadPack.buildLeague(slices: src.slices, excluding: team?.rawValue,
                                               personalise: personalise)

        guard let team else { return }

        // Team page: the cache His Team already keeps, refreshed when stale.
        var page = TeamPageCache.load(teamId: team.rawValue)
        if page == nil || page!.isStale {
            if let fresh = try? await APIClient.shared.fetchTeamPage(teamId: team.rawValue) {
                TeamPageCache.save(content: fresh, teamId: team.rawValue)
                page = TeamPageCache.load(teamId: team.rawValue)
            }
        }
        guard let content = page?.content else { return }

        // Manager photo: check the bytes once per URL. Player photos are not
        // checked — all 60 PL ones-to-know photos were real on 2026-09-08.
        if let photo = content.cards.manager?.photoURL, let url = URL(string: photo),
           !src.silhouettes.contains(photo), !(checkedPhotos.contains(photo)) {
            checkedPhotos.insert(photo)
            if let (data, _) = try? await URLSession.shared.data(from: url), LiveClubPack.isSilhouette(data) {
                src.silhouettes.append(photo)
                sources = src
            }
        }

        pack = LiveClubPack.build(team: team, page: content, sources: src, personalise: personalise)
    }

    private var checkedPhotos: Set<String> = []

    private static func fetchSources() async throws -> LiveClubPack.Sources {
        let ids = Team.allCases.map(\.rawValue).joined(separator: ",")
        let slicesData = try await APIClient.shared.rawGET(path: "team_pages", queryItems: [
            URLQueryItem(name: "select", value: "team_id,manager:content->cards->manager,players:content->cards->ones_to_know->players,basics:content->cards->basics,rival:content->cards->rivalry->>rival"),
            URLQueryItem(name: "team_id", value: "in.(\(ids))"),
        ])
        let managersData = try await APIClient.shared.rawGET(path: "teams", queryItems: [
            URLQueryItem(name: "select", value: "id,display_name,short_name,manager_name"),
            URLQueryItem(name: "is_active", value: "eq.true"),
            URLQueryItem(name: "league_id", value: "eq.39"),
        ])
        let decoder = JSONDecoder()
        return LiveClubPack.Sources(
            managers: try decoder.decode([LiveClubPack.ClubManager].self, from: managersData),
            slices: try decoder.decode([LiveClubPack.Slice].self, from: slicesData),
            fetchedAt: Date()
        )
    }
}
