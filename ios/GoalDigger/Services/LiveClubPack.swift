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
        /// Who this club play next, for "Who's next?" distractors. Nil on a page
        /// written before the fixture was known.
        var next: String? = nil
    }

    /// Who leads a club's scoring, and whether anyone is level with him. A tie
    /// is never called "top scorer", so the question is skipped instead.
    struct TopScorer: Codable, Hashable {
        let team_id: String
        let name: String
        let goals: Int
        let tied: Bool
        /// Squad-mates, most-played first, for the question's wrong answers.
        /// Same source as `name`, so they are printed the same way.
        var rivals: [String] = []
        /// His photo once checked not to be the CDN silhouette, and his shirt
        /// number under the squad pack's rule. Nil until a fetch fills them.
        var photo: String? = nil
        var number: Int? = nil
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
        /// Two men per club, chosen and photo-checked at fetch time, for the
        /// league pack. Only the survivors are kept, so this is forty rows.
        var leaguePicks: [LiveSquadPack.Player] = []
        /// Every club's leading scorer, keyed by team id.
        var topScorers: [String: TopScorer] = [:]

        var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 24 * 60 * 60 }
    }

    /// One club's players, out of the league-wide cache and nothing else.
    /// A plain value so `Sources` — which carries twenty pages, every manager
    /// and 1500 squad rows — stays private to its service.
    struct ClubPlayers: Equatable {
        var picks: [LiveSquadPack.Player] = []
        var curated: [TopPlayer] = []

        static func == (a: Self, b: Self) -> Bool {
            a.picks == b.picks && a.curated.map(\.name) == b.curated.map(\.name)
        }
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
            // The page's prose is colour and is not in her mouth: the line she
            // says is ours, from the table, never a talking point that narrates
            // him ("which Tom will find impressive").
            let summary = clip(personalise(m.summary), 150)
            let rank = cards.standings?.entries.first {
                $0.teamIdApiFootball == team.apiFootballId || MatchContext.sameClub($0.teamName, team.displayName)
            }?.rank
            let surname = m.name.split(separator: " ").last.map(String.init) ?? m.name
            let line = rank.map { $0 <= 4 ? "\(surname)'s got us flying. Is he staying long?"
                : $0 >= 17 ? "Is \(surname) under pressure yet?" : "What do you make of \(surname) so far?" }
                ?? "What do you make of \(surname) so far?"
            qs += question(
                id: "live-manager-name", difficulty: 1,
                question: "Who manages \(club)?",
                answer: m.name, distractors: rivalsManagers,
                explanation: (["\(m.name) is \(club)'s manager.", summary].filter { !$0.isEmpty }).joined(separator: " "),
                why: "The manager is the one he'll praise or blame after every single match.",
                useType: .ask,
                use: quote(line)
            )
        }

        // The state of the club, right now. Every one of these changes on a
        // Saturday, which is the point: the people live in the squad pack.
        // Not `teamName == displayName`: the feed spells seven of the twenty
        // its own way ("Bournemouth", "Brighton", "Newcastle").
        let mine = cards.standings?.entries.first {
            $0.teamIdApiFootball == team.apiFootballId
                || MatchContext.sameClub($0.teamName, team.displayName)
        }
        if let row = mine, row.rank > 0 {
            let nearby = [-3, -2, -1, 1, 2, 3, 4].map { row.rank + $0 }.filter { (1...20).contains($0) }
            qs += question(
                id: "live-table-position", difficulty: 2,
                question: "Where are \(club) in the table right now?",
                answer: ordinal(row.rank), distractors: nearby.map(ordinal),
                explanation: "\(club) are \(ordinal(row.rank)) with \(points(row.points)) from \(row.played) games.",
                why: "The table is the first thing he checks, and it moves every weekend.",
                useType: .ask,
                // Not "Are we still 8th?", which asks what the card just said.
                use: quote(row.rank <= 4 ? "Can we stay up there till May?"
                           : row.rank >= 18 ? "How worried should we be about the table?"
                           : "Where do you reckon we'll finish this season?")
            )
            qs += question(
                id: "live-points", difficulty: 3,
                question: "How many points do \(club) have?",
                answer: "\(row.points)",
                distractors: [3, -3, 6, -6, 1, -1].map { row.points + $0 }.filter { $0 >= 0 }.map(String.init),
                explanation: "\(points(row.points)) from \(row.played) games, which has them \(ordinal(row.rank)) as of today.",
                why: "Three for a win, one for a draw. The number is the whole season in one figure.",
                useType: .impress,
                // The verdict follows the points per game, not a fixed line:
                // "a decent start" was said of clubs in the bottom three.
                use: quote("\(points(row.points)) from \(row.played). " + {
                    let ppg = row.played > 0 ? Double(row.points) / Double(row.played) : 0
                    return ppg >= 2.3 ? "That's a brilliant start." : ppg >= 1.6 ? "That's a good start."
                        : ppg >= 1.1 ? "That's a decent start." : "That's not the start we wanted."
                }())
            )
        }

        // The last game. She is expected to know the result, not just the name
        // of the opponent, so the wrong answers keep the opponent and change
        // the outcome.
        let recent = cards.recentResults ?? []
        if let last = recent.first {
            var wrong = [resultLine(last, flip: .loss), resultLine(last, flip: .draw), resultLine(last, flip: .win)]
            for r in recent.dropFirst() { wrong += [resultLine(r), resultLine(r, flip: .loss)] }
            qs += question(
                id: "live-last-result", difficulty: 2,
                question: "Who did \(club) play last, and how did it go?",
                answer: resultLine(last), distractors: wrong,
                explanation: "\(club) played \(clubShort(last.opponent)) \(last.venue == "home" ? "at home" : "away") and it finished \(last.teamScore)-\(last.oppScore). That is the game he is still talking about.",
                why: "The last result decides what kind of week he has had.",
                useType: .ask,
                use: quote(last.outcome == "W" ? "Still buzzing about the \(clubShort(last.opponent)) game?"
                           : last.outcome == "D" ? "Was the draw with \(clubShort(last.opponent)) fair?"
                           : "Have you got over the \(clubShort(last.opponent)) game yet?")
            )
        }

        if let next = cards.nextFixture {
            let opponent = clubShort(next.opponent)
            qs += question(
                id: "live-next-opponent", difficulty: 2,
                question: "Who do \(club) play next?",
                answer: opponent,
                distractors: (others.compactMap(\.next).map(clubShort) + Team.allCases.map(\.shortName))
                    .filter { $0 != club },
                explanation: [
                    "\(club) play \(opponent) \(next.venue.lowercased() == "away" ? "away" : "at home")",
                    next.competition.map { "in the \($0)" },
                ].compactMap { $0 }.joined(separator: " ") + ". That is the next one in the diary.",
                why: "Whatever the plan was for that afternoon, this is what it is now.",
                useType: .ask,
                use: quote("Is the \(opponent) game on the telly?")
            )
        }

        // How they have been playing: five letters on the team page, in words.
        if let f = cards.form {
            let letters = f.recentForm.uppercased().filter { "WDL".contains($0) }
            let w = letters.filter { $0 == "W" }.count
            let d = letters.filter { $0 == "D" }.count
            let l = letters.filter { $0 == "L" }.count
            if letters.count >= 3 {
                let answer = formLabel(w, d, l)
                let wrong = [(w + 1, d - 1, l), (w - 1, d + 1, l), (w, d + 1, l - 1),
                             (w, d - 1, l + 1), (w - 1, d, l + 1), (w + 1, d, l - 1)]
                    .filter { $0.0 >= 0 && $0.1 >= 0 && $0.2 >= 0 }
                    .map { formLabel($0.0, $0.1, $0.2) }
                qs += question(
                    id: "live-form", difficulty: 2,
                    question: "How have \(club) been playing?",
                    answer: answer, distractors: wrong,
                    explanation: ["\(answer), as of today.", clip(personalise(f.formSummary), 110)]
                        .filter { !$0.isEmpty }.joined(separator: " "),
                    why: "Form is the mood. It explains why he is fine or unbearable this week.",
                    useType: .ask,
                    // The line follows the form: "playing well, or just winning?"
                    // was asked of clubs that had not won.
                    use: quote(w * 2 > letters.count ? "We've been flying lately, haven't we?"
                               : l * 2 > letters.count ? "It's been a rough few weeks, hasn't it?"
                               : "Up and down lately. What's going wrong?")
                )
            }
        }

        // Who has the goals. Skipped on a tie: "joint top scorer" is not a
        // question with one right answer.
        if let scorer = sources.topScorers[team.rawValue], !scorer.tied, scorer.goals > 0 {
            qs += question(
                id: "live-top-scorer", difficulty: 2,
                question: "Who's scored most for \(club) this season?",
                answer: shortName(scorer.name), distractors: scorer.rivals.map(shortName),
                explanation: "\(shortName(scorer.name)) has \(scorer.goals) \(scorer.goals == 1 ? "goal" : "goals") for \(club) this season, more than anyone else in the squad.",
                why: "When the ball goes in, this is the name the room shouts most often.",
                useType: .say,
                use: "When they win a corner: " + quote("Watch \(shortName(scorer.name)) here.")
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
                        : (.ask, quote("Do you think we'll win it again soon?"))
                qs += question(
                    id: "live-last-title", difficulty: 3,
                    question: "When did \(club) last win the league?",
                    answer: title, distractors: otherBasics.compactMap(\.lastTitle),
                    explanation: never
                        ? "\(club) have never won the top-flight title."
                        : "\(club) were champions in \(year).",
                    why: "It's the first thing a rival fan brings up, so he has an answer ready.",
                    useType: use.0, use: use.1
                )
            }
            let nick = cleanNickname(b.nickname)
            if !b.nickname.lowercased().contains(club.lowercased()) {
            qs += question(
                id: "live-nickname", difficulty: 1,
                question: "What are \(club) known as?",
                answer: b.nickname, distractors: otherBasics.map(\.nickname),
                explanation: "\(club) are \(b.nickname). Commentators and fans use it without thinking, so he will too.",
                why: "Half the time he won't say the club's name at all.",
                useType: .say,
                use: quote("Come on you \(nick)!")
            )
            }
            if let ground = b.stadium {
                let short = stadiumShort(ground)
                qs += question(
                    id: "live-stadium", difficulty: 1,
                    question: "Where do \(club) play their home games?",
                    answer: short, distractors: otherBasics.compactMap(\.stadium).map(stadiumShort),
                    explanation: "\(ground). When he says \"we're at home\", this is where he means.",
                    why: "Home or away is the first thing he'll say about any fixture.",
                    useType: .ask,
                    use: quote("Have you ever been to \(withArticle(short))?")
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

    // MARK: The opponent

    static let opponentPackId = "live-opponent"

    /// "Get to know Chelsea": the side he is about to watch his club play,
    /// built from the opponent's own cached page and the league-wide sources.
    ///
    /// Facts only. The opponent's page is written for someone who follows
    /// *them* — its summaries say "[his name]" meaning a Chelsea fan — so no
    /// prose is lifted from it: every explanation is built here from numbers
    /// and names. And only the questions that are about the other side: not
    /// their rival or their next fixture (that is us), not their last title.
    /// `mine` is his club, kept out of the distractors so her own manager is
    /// never offered as the other side's.
    /// `lastMeeting` comes off his own page's matchup card, not theirs: only
    /// his is written for this fixture.
    static func buildOpponent(team: Team, page: TeamPageContent, sources: Sources, mine: Team?,
                              lastMeeting: MatchContext.LastMeeting? = nil) -> QuizPack? {
        let cards = page.cards
        let club = team.shortName
        let others = sources.slices.filter { $0.team_id != team.rawValue }
        var qs: [MyTurnQuestion] = []
        // Two options, not three: she knows nothing about the other side, and
        // one in three was a guess (Anton, 2026-10-02).
        func two(id: String, difficulty: Int, question q: String, answer: String, distractors: [String],
                 explanation: String, why: String, useType: QuestionUseType, use: String,
                 image: String? = nil) -> [MyTurnQuestion] {
            question(id: id, difficulty: difficulty, question: q, answer: answer, distractors: distractors,
                     explanation: explanation, why: why, useType: useType, use: use, image: image, options: 2)
        }

        if let m = cards.manager {
            let wrong = sources.managers
                .filter { $0.id != team.rawValue && $0.id != mine?.rawValue }
                .compactMap(\.manager_name).filter { $0 != m.name }
            qs += two(
                id: "opp-manager", difficulty: 1,
                question: "Who manages \(club)?",
                answer: m.name, distractors: wrong,
                explanation: "\(m.name). He'll be in the other dugout, and the cameras cut to him every time they score.",
                why: "After the game, the other manager is the one he'll either blame or grudgingly rate.",
                useType: .ask, use: quote("What do you make of \(m.name)?"),
                // His face, so she knows him when the camera finds him.
                image: PlayerPortrait.source(club: team.rawValue, name: m.name)
                    ?? m.photoURL.flatMap { !$0.isEmpty && !sources.silhouettes.contains($0) ? $0 : nil })
        }

        let row = cards.standings?.entries.first {
            $0.teamIdApiFootball == team.apiFootballId || MatchContext.sameClub($0.teamName, team.displayName)
        }
        if let row, row.rank > 0 {
            let nearby = [-3, -2, -1, 1, 2, 3, 4].map { row.rank + $0 }.filter { (1...20).contains($0) }
            qs += two(
                id: "opp-table-position", difficulty: 2,
                question: "Where are \(club) in the table right now?",
                answer: ordinal(row.rank), distractors: nearby.map(ordinal),
                explanation: "\(club) are \(ordinal(row.rank)) with \(points(row.points)) from \(row.played) games, as of today.",
                why: "Where they sit tells you whether a draw would be a good result or a bad one.",
                useType: .ask, use: quote("They're \(ordinal(row.rank)), aren't they? Should we be beating them?"))
        }

        // The form, told through the games themselves: "Leeds have played
        // Wolves, Fulham and Burnley" with how it went, rather than a W/D/L
        // count she could only guess at (Anton, 2026-10-02).
        if let results = cards.recentResults, results.count >= 3 {
            qs += formFromResults(Array(results.prefix(3)), club: club)
        } else if let f = cards.form {
            let letters = f.recentForm.uppercased().filter { "WDL".contains($0) }
            let w = letters.filter { $0 == "W" }.count, d = letters.filter { $0 == "D" }.count
            let l = letters.filter { $0 == "L" }.count
            if letters.count >= 3 {
                let answer = formLabel(w, d, l)
                let wrong = [(w + 1, d - 1, l), (w - 1, d + 1, l), (w, d + 1, l - 1),
                             (w, d - 1, l + 1), (w - 1, d, l + 1), (w + 1, d, l - 1)]
                    .filter { $0.0 >= 0 && $0.1 >= 0 && $0.2 >= 0 }.map { formLabel($0.0, $0.1, $0.2) }
                qs += two(
                    id: "opp-form", difficulty: 2,
                    question: "How have \(club) been playing lately?",
                    answer: answer, distractors: wrong,
                    explanation: "\(answer), as of today.",
                    why: "Their form is how nervous he'll be before kick-off.",
                    useType: .ask, use: quote("Are \(club) in form at the moment? Should I be worried?"))
            }
        }

        if let scorer = sources.topScorers[team.rawValue], !scorer.tied, scorer.goals > 0 {
            let name = shortName(scorer.name)
            // His face from the question on, and his number in the answer: what
            // she needs is to spot him on Saturday (Anton, 2026-10-02).
            let shirt = scorer.number.map { ", number \($0)," } ?? ","
            qs += two(
                id: "opp-top-scorer", difficulty: 2,
                question: "Who's scored most for \(club) this season?",
                answer: name, distractors: scorer.rivals.map(shortName),
                explanation: "\(name)\(shirt) with \(scorer.goals) \(scorer.goals == 1 ? "goal" : "goals") for \(club) this season, more than anyone else in their squad.",
                why: "He's the one to worry about when they come forward.",
                useType: .say, use: "When they attack: " + quote("Watch \(name). He's their scorer."),
                image: PlayerPortrait.source(club: team.rawValue, name: scorer.name) ?? scorer.photo)
        }

        // How it went last time they met, which is what he'll bring up. Only
        // when there's no meeting on the card: where they finished last season
        // — the place alone. "14th, 47 points" was a question nobody could
        // make anything of (Anton, 2026-09-29).
        if let m = lastMeeting, let mine {
            qs += lastMeetingQuestion(m, club: club, ours: mine.shortName)
        } else if let last = cards.basics?.lastSeason, let place = leadingPlace(last) {
            let nearby = [-3, -2, -1, 1, 2, 3, 4].map { place + $0 }.filter { (1...20).contains($0) }
            qs += two(
                id: "opp-last-season", difficulty: 2,
                question: "Where did \(club) finish last season?",
                answer: ordinal(place), distractors: nearby.map(ordinal),
                explanation: "\(club) finished \(ordinal(place)) in the Premier League last season.",
                why: "It tells you what kind of side we're up against, before a ball is kicked.",
                useType: .ask, use: quote("Were \(club) any good last season?"))
        }

        if let b = cards.basics {
            let otherBasics = others.compactMap(\.basics)
            let nick = cleanNickname(b.nickname)
            // "What are Spurs known as? Spurs (or Lilywhites)" answers itself.
            if !b.nickname.lowercased().contains(club.lowercased()) {
            qs += two(
                id: "opp-nickname", difficulty: 1,
                question: "What are \(club) known as?",
                answer: b.nickname, distractors: otherBasics.map(\.nickname),
                explanation: "\(club) are \(b.nickname). The commentators will say it all game.",
                why: "Half the time nobody says their name, just the nickname.",
                useType: .say, use: quote("So we're playing the \(nick). Got it."))
            }
            if let ground = b.stadium {
                let short = stadiumShort(ground)
                qs += two(
                    id: "opp-stadium", difficulty: 1,
                    question: "Where do \(club) play their home games?",
                    answer: short, distractors: otherBasics.compactMap(\.stadium).map(stadiumShort),
                    explanation: "\(ground).",
                    why: "Whether the game is at theirs or ours changes how he feels about it.",
                    useType: .ask, use: quote("Have you ever been to \(withArticle(short))?"))
            }
        }

        guard qs.count >= 4 else { return nil }
        return QuizPack(id: opponentPackId, label: "Get to know \(club)", questions: qs)
    }

    /// "We won 4–0", with the flipped result and a draw as the other two, so
    /// every option is a scoreline that could have happened in that game.
    static func lastMeetingQuestion(_ m: MatchContext.LastMeeting, club: String, ours: String) -> [MyTurnQuestion] {
        let hi = max(m.ours, m.theirs), lo = min(m.ours, m.theirs)
        let score = "\(hi)\u{2013}\(lo)"
        let answer: String, wrong: [String], line: String
        if m.ours > m.theirs {
            answer = "We won \(score)"; wrong = ["They won \(score)", "\(lo)\u{2013}\(lo) draw"]
            line = "We beat them \(score) last time. Can we do it again?"
        } else if m.theirs > m.ours {
            answer = "They won \(score)"; wrong = ["We won \(score)", "\(lo)\u{2013}\(lo) draw"]
            line = "They beat us last time. Is this the revenge game?"
        } else {
            let won = "\(hi + 1)\u{2013}\(hi)"
            answer = "\(score) draw"; wrong = ["We won \(won)", "They won \(won)"]
            line = "It was a draw last time. Can we beat them this time?"
        }
        let (home, away) = m.weAreHome ? (ours, club) : (club, ours)
        let (hg, ag) = m.weAreHome ? (m.ours, m.theirs) : (m.theirs, m.ours)
        let when = monthYear(m.date).map { ", in \($0)" } ?? ""
        return question(
            id: "opp-last-meeting", difficulty: 2,
            question: "The last time \(ours) played \(club), how did it go?",
            answer: answer, distractors: Array(wrong.prefix(1)),
            explanation: "\(home) \(hg)\u{2013}\(ag) \(away), at \(m.weAreHome ? "ours" : "theirs")\(when).",
            why: "He'll remember it, and he'll bring it up before kick-off.",
            useType: .ask, use: quote(line), options: 2)
    }

    /// Their last three, by name: "Leeds have played Wolves, Fulham and
    /// Burnley. How did it go?" The answer is how many they won, drew and
    /// lost, against its mirror; the explanation is the three scores, and the
    /// line to say is the mood of it.
    static func formFromResults(_ results: [RecentResult], club: String) -> [MyTurnQuestion] {
        let w = results.filter { $0.outcome == "W" }.count
        let d = results.filter { $0.outcome == "D" }.count
        let l = results.filter { $0.outcome == "L" }.count
        let answer = formLabel(w, d, l)
        // The mirror swaps wins and losses; level ones tip one way instead.
        let mirror = w != l ? formLabel(l, d, w) : d > 0 ? formLabel(w + 1, d - 1, l) : formLabel(w + 1, d, l - 1)
        let names = results.map(\.opponent)
        let list = names.count == 3 ? "\(names[0]), \(names[1]) and \(names[2])" : names.joined(separator: ", ")
        let told = results.map { r -> String in
            let score = "\(r.teamScore)\u{2013}\(r.oppScore)"
            switch r.outcome {
            case "W": return "beat \(r.opponent) \(score)"
            case "L": return "lost \(score) to \(r.opponent)"
            default: return "drew \(score) with \(r.opponent)"
            }
        }.joined(separator: ", ")
        let line = w >= 2 ? "They've been flying lately, haven't they?"
            : l >= 2 ? "They've had a rough few weeks, haven't they?"
            : "They've been up and down lately, haven't they?"
        return question(
            id: "opp-form", difficulty: 2,
            question: "\(club) have played \(list). How did it go?",
            answer: answer, distractors: [mirror],
            explanation: "They \(told).",
            why: "Their form is how nervous he'll be before kick-off.",
            useType: .say, use: quote(line), options: 2)
    }

    /// "14th, 47 points" → 14. Nil for anything that isn't a plain Premier
    /// League place first — "Champions, 85 points", "Promoted through the
    /// play-offs, 6th" and "Championship runners-up" all say something the
    /// place alone would get wrong.
    static func leadingPlace(_ s: String) -> Int? {
        guard let r = s.range(of: #"^\d{1,2}(st|nd|rd|th),"#, options: .regularExpression) else { return nil }
        return Int(s[r].prefix { $0.isNumber })
    }

    /// "2026-01-31" → "January 2026".
    static func monthYear(_ ymd: String) -> String? {
        let parts = ymd.split(separator: "-")
        guard parts.count >= 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        // English whatever the phone's language: the rest of the sentence is.
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB")
        return "\(f.standaloneMonthSymbols[m - 1]) \(y)"
    }

    #if DEBUG
    /// The opponent pack from a fixture page: facts only, opponent ids only,
    /// and nothing that speaks as though she follows the other side.
    static func opponentSelfCheck(page: TeamPageContent) -> Bool {
        let src = Sources(managers: [], slices: [], fetchedAt: Date())
        guard let pack = buildOpponent(team: .chelsea, page: page, sources: src, mine: .arsenal) else {
            return page.cards.basics == nil  // too little on the fixture to build is fine, not a failure
        }
        let text = pack.questions.flatMap { [$0.question, $0.explanation, $0.why ?? "", $0.use ?? ""] }.joined(separator: " ")
        // Leeds 0–4 Arsenal away: ours is the win, and the flip is offered.
        let meeting = lastMeetingQuestion(.init(date: "2026-01-31", weAreHome: false, ours: 4, theirs: 0),
                                          club: "Leeds", ours: "Arsenal").first
        let meetingOK = meeting.map {
            $0.options[$0.answer] == "We won 4\u{2013}0" && $0.options.contains("They won 4\u{2013}0")
                && ($0.use ?? "").contains("Can we do it again")
                && $0.explanation == "Leeds 0\u{2013}4 Arsenal, at theirs, in January 2026."
        } ?? false
        let form = formFromResults([
            RecentResult(date: "2026-09-27", opponent: "Wolves", venue: "home", teamScore: 2, oppScore: 0),
            RecentResult(date: "2026-09-20", opponent: "Fulham", venue: "away", teamScore: 1, oppScore: 1),
            RecentResult(date: "2026-09-13", opponent: "Burnley", venue: "home", teamScore: 3, oppScore: 1)],
            club: "Leeds").first
        let formOK = form.map {
            $0.question == "Leeds have played Wolves, Fulham and Burnley. How did it go?"
                && $0.options[$0.answer] == "Won 2, drew 1, lost 0 of the last three"
                && $0.options.count == 2 && $0.explanation.hasPrefix("They beat Wolves 2\u{2013}0")
        } ?? false
        return meetingOK && formOK && leadingPlace("14th, 47 points") == 14 && leadingPlace("Champions, 85 points") == nil
            && leadingPlace("Promoted through the play-offs, 6th") == nil
            && pack.questions.allSatisfy { $0.id.hasPrefix("opp-") && $0.options.count == 2 }
            && !text.contains("[his") && !text.contains("Come on you")
    }
    #endif

    // MARK: Question assembly

    /// One question, or nothing if fewer than two distinct distractors exist.
    /// Three options, like every static question since 2026-09-23 (Anton: three
    /// in Quiz); this builder was missed then and kept dealing four.
    /// Options are shuffled with a generator seeded from the id so the order is
    /// stable across launches and re-renders. Shared with `LiveSquadPack`.
    static func question(id: String, difficulty: Int, question: String, answer: String,
                         distractors: [String], explanation: String, why: String,
                         useType: QuestionUseType, use: String, image: String? = nil,
                         player: QuizPlayer? = nil, options optionCount: Int = 3) -> [MyTurnQuestion] {
        var seen: Set<String> = [answer.lowercased()]
        var picks: [String] = []
        var rng = SeededGenerator(seed: id)
        for d in distractors.shuffled(using: &rng) where d.count <= 40 && !seen.contains(d.lowercased()) {
            seen.insert(d.lowercased()); picks.append(d)
            if picks.count == optionCount - 1 { break }
        }
        guard picks.count == optionCount - 1, answer.count <= 40 else { return [] }
        var options = picks + [answer]
        options.shuffle(using: &rng)
        return [MyTurnQuestion(id: id, difficulty: difficulty, question: question, options: options,
                               answer: options.firstIndex(of: answer)!, explanation: explanation,
                               why: why, use: use, useType: useType, image: image, player: player)]
    }

    // MARK: Text helpers

    static func quote(_ s: String) -> String { "\u{201C}\(s)\u{201D}" }

    /// 1 → "1st", 2 → "2nd", 11 → "11th".
    static func ordinal(_ n: Int) -> String {
        let suffix = (11...13).contains(n % 100) ? "th"
            : n % 10 == 1 ? "st" : n % 10 == 2 ? "nd" : n % 10 == 3 ? "rd" : "th"
        return "\(n)\(suffix)"
    }

    static func points(_ n: Int) -> String { n == 1 ? "1 point" : "\(n) points" }

    /// "Wolverhampton Wanderers" → "Wolves", so a result line fits the forty
    /// characters an option gets. Anything we do not recognise is left alone.
    static func clubShort(_ name: String) -> String {
        Team.allCases.first {
            $0.displayName.caseInsensitiveCompare(name) == .orderedSame
                || $0.shortName.caseInsensitiveCompare(name) == .orderedSame
        }?.shortName ?? name
    }

    enum Flip { case win, draw, loss }

    /// "Beat Chelsea 2-1 (home)". `flip` rewrites the outcome for a distractor:
    /// same opponent, same afternoon, a result that did not happen.
    static func resultLine(_ r: RecentResult, flip: Flip? = nil) -> String {
        let opp = clubShort(r.opponent)
        let where_ = r.venue.lowercased() == "away" ? "away" : "home"
        let hi = max(r.teamScore, r.oppScore), lo = min(r.teamScore, r.oppScore)
        switch flip ?? (r.outcome == "W" ? .win : r.outcome == "L" ? .loss : .draw) {
        // A 1-1 cannot be flipped to "Beat them 1-1", so a level score gains
        // a goal for the win and loss variants.
        case .win:  return "Beat \(opp) \(hi == lo ? hi + 1 : hi)-\(lo) (\(where_))"
        case .loss: return "Lost \(lo)-\(hi == lo ? hi + 1 : hi) to \(opp) (\(where_))"
        case .draw: return "Drew \(hi)-\(hi) with \(opp) (\(where_))"
        }
    }

    /// "Won 3, drew 1, lost 1 of the last five".
    static func formLabel(_ w: Int, _ d: Int, _ l: Int) -> String {
        let words = ["", "one", "two", "three", "four", "five", "six"]
        let n = w + d + l
        return "Won \(w), drew \(d), lost \(l) of the last \(words[safe: n] ?? "\(n)")"
    }

    /// The whole sentences that fit under the cap, or nothing. Never a cut
    /// with an ellipsis: the pre-launch audit found ~40 answers a club ending
    /// "…as Hull adapt to Premier…" (2026-10-02). A caller that needs text
    /// leads with its own fact and treats this as the optional colour.
    static func clip(_ text: String, _ cap: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > cap else { return t }
        let head = String(t.prefix(cap))
        if let end = head.lastIndex(where: { ".!?".contains($0) }) {
            return String(head[...end])
        }
        return ""
    }

    /// "Gtech Community Stadium" → "the Gtech Community Stadium"; "Anfield",
    /// "Villa Park" and "The City Ground" stay as they are.
    static func withArticle(_ ground: String) -> String {
        let g = ground.trimmingCharacters(in: .whitespaces)
        if g.lowercased().hasPrefix("the ") { return g }
        let needs = ["Stadium", "Arena", "Ground", "Community"].contains { g.contains($0) }
        return needs ? "the " + g : g
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
    /// "The league's big names" — two men from every other club, built from
    /// the same daily `players` fetch that gives this pack its top scorer.
    private(set) var leaguePack: QuizPack?
    private(set) var teamId: String?
    /// The cached team page this refresh loaded, kept so a second consumer does
    /// not have to reach into `TeamPageCache` itself. Lingo's weekend context
    /// is built from it (`MatchContext`).
    private(set) var page: TeamPageContent?
    /// "Get to know Chelsea", for the fixture the prep section is about. Built
    /// by `refreshOpponent`, which the prep calls with the context's opponent
    /// (never `next_fixture`'s: the two part company on a postponement).
    private(set) var opponentPack: QuizPack?
    private var opponentId: String?

    private static let sourcesKey = "myTurnLiveSources.v2"
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
        pack = nil; leaguePack = nil; teamId = nil; page = nil; sources = nil
        opponentPack = nil; opponentId = nil
        UserDefaults.standard.removeObject(forKey: Self.sourcesKey)
    }

    func refresh(team: Team?, personalise: @escaping (String) -> String) async {
        // Switching club starts a second refresh while this one is awaiting a
        // fetch. Whoever is no longer the selected club writes nothing: the
        // loser of the race would otherwise publish the old club's page and
        // pack over the new club's.
        let requested = team?.rawValue
        teamId = requested
        if team == nil { pack = nil; page = nil }
        // Publish whatever is cached before anything is fetched, so Lingo has
        // its weekend context on a cold, offline launch too.
        page = team.flatMap { TeamPageCache.load(teamId: $0.rawValue)?.content }

        // League-wide sources, at most once a day. They also carry the league
        // pack, which is worth having whether or not she follows a club.
        if sources == nil || sources!.isStale {
            if let fresh = try? await Self.fetchSources() {
                var merged = fresh
                merged.silhouettes = sources?.silhouettes ?? []
                sources = merged
            }
            guard teamId == requested else { return }
        }
        guard var src = sources else { return }
        leaguePack = LiveSquadPack.buildLeague(
            picks: src.leaguePicks, topScorers: src.topScorers,
            liners: Dictionary(src.slices.map { ($0.team_id, $0.players ?? []) }, uniquingKeysWith: { a, _ in a }),
            excluding: team?.rawValue, personalise: personalise)

        guard let team else { return }

        // Team page: the cache His Team already keeps, refreshed when stale.
        var cached = TeamPageCache.load(teamId: team.rawValue)
        if cached == nil || cached!.isStale {
            if let fresh = try? await APIClient.shared.fetchTeamPage(teamId: team.rawValue) {
                TeamPageCache.save(content: fresh, teamId: team.rawValue)
                cached = TeamPageCache.load(teamId: team.rawValue)
            }
            guard teamId == requested else { return }
        }
        page = cached?.content
        guard let content = cached?.content else { return }

        // Manager photo: check the bytes once per URL. Player photos are not
        // checked — all 60 PL ones-to-know photos were real on 2026-09-08.
        if let photo = content.cards.manager?.photoURL, let url = URL(string: photo),
           !src.silhouettes.contains(photo), !(checkedPhotos.contains(photo)) {
            checkedPhotos.insert(photo)
            if let (data, _) = try? await URLSession.shared.data(from: url), LiveClubPack.isSilhouette(data) {
                src.silhouettes.append(photo)
                sources = src
            }
            guard teamId == requested else { return }
        }

        pack = LiveClubPack.build(team: team, page: content, sources: src, personalise: personalise)
    }

    /// Build the opponent pack for `opponent`, loading its team page from the
    /// cache His Team keeps (fetched when stale). Nil opponent, or one that is
    /// not a club we have a page for (a cup tie against a lower-league side),
    /// clears it.
    func refreshOpponent(_ opponent: Team?, mine: Team?, lastMeeting: MatchContext.LastMeeting? = nil) async {
        opponentId = opponent?.rawValue
        guard let opponent else { opponentPack = nil; return }
        var cached = TeamPageCache.load(teamId: opponent.rawValue)
        if cached == nil || cached!.isStale {
            if let fresh = try? await APIClient.shared.fetchTeamPage(teamId: opponent.rawValue) {
                TeamPageCache.save(content: fresh, teamId: opponent.rawValue)
                cached = TeamPageCache.load(teamId: opponent.rawValue)
            }
        }
        // A newer call for another opponent owns the result.
        guard opponentId == opponent.rawValue else { return }
        guard let content = cached?.content, let src = sources else { opponentPack = nil; return }
        opponentPack = LiveClubPack.buildOpponent(team: opponent, page: content, sources: src, mine: mine,
                                                  lastMeeting: lastMeeting)
    }

    /// One club's players out of the cached league-wide sources: the two men
    /// the league pack picked, and that club's own three curated players.
    /// Read-only, so `sources` stays private. Empty before the first fetch and
    /// for a club id nothing was cached for.
    func clubPlayers(teamId: String) -> LiveClubPack.ClubPlayers {
        guard let sources else { return .init() }
        return .init(picks: sources.leaguePicks.filter { $0.team_id == teamId },
                     curated: sources.slices.first { $0.team_id == teamId }?.players ?? [])
    }

    private var checkedPhotos: Set<String> = []

    private static func fetchSources() async throws -> LiveClubPack.Sources {
        let ids = Team.allCases.map(\.rawValue).joined(separator: ",")
        let slicesData = try await APIClient.shared.rawGET(path: "team_pages", queryItems: [
            URLQueryItem(name: "select", value: "team_id,manager:content->cards->manager,players:content->cards->ones_to_know->players,basics:content->cards->basics,rival:content->cards->rivalry->>rival,next:content->cards->next_fixture->>opponent"),
            URLQueryItem(name: "team_id", value: "in.(\(ids))"),
        ])
        let managersData = try await APIClient.shared.rawGET(path: "teams", queryItems: [
            URLQueryItem(name: "select", value: "id,display_name,short_name,manager_name"),
            URLQueryItem(name: "is_active", value: "eq.true"),
            URLQueryItem(name: "league_id", value: "eq.39"),
        ])
        // Every active club's squad, once a day. `select=*` rather than a column
        // list for the same reason the squad fetch uses it: naming a column
        // PostgREST does not have yet is a 400 for the whole request, and the
        // stats columns are still arriving.
        let playersData = try await APIClient.shared.rawGET(path: "players", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "team_id", value: "in.(\(ids))"),
            URLQueryItem(name: "order", value: "minutes.desc"),
            URLQueryItem(name: "limit", value: "1500"),
        ])
        let decoder = JSONDecoder()
        let rows = ((try? decoder.decode([LiveSquadPack.Player].self, from: playersData)) ?? [])
            .filter { $0.in_official_squad != false }

        // Pick a handful per club, then spend the photo checks only on those.
        // Whoever comes back a silhouette drops out and the next man stands in.
        let checked = await LiveSquadService.flagPlaceholders(LiveSquadPack.leagueCandidates(from: rows))
        // Each club's top scorer is asked about over his photo, so his photo
        // gets the same silhouette check: twenty more small fetches a day.
        var scorers = LiveSquadPack.topScorers(from: rows)
        let scorerRows = rows.filter { p in p.team_id.flatMap { scorers[$0]?.name } == p.name }
        for p in await LiveSquadService.flagPlaceholders(scorerRows) where p.photoIsPlaceholder != true {
            if let t = p.team_id { scorers[t]?.photo = p.photo_url }
        }
        return LiveClubPack.Sources(
            managers: try decoder.decode([LiveClubPack.ClubManager].self, from: managersData),
            slices: try decoder.decode([LiveClubPack.Slice].self, from: slicesData),
            fetchedAt: Date(),
            leaguePicks: LiveSquadPack.leaguePicks(from: checked),
            topScorers: scorers
        )
    }
}
