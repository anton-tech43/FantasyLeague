import Foundation

// MARK: - The calendar bits that rot
//
/// Transfer windows and season shape, in one place because nothing upstream
/// tells the app when they move: API-Football has no "the window is open"
/// field, so these are hand-maintained. The `stale-data-audit` skill lists
/// this enum among the surfaces it checks. Last verified 2026-09-22.
enum LingoCalendar {
    /// Summer window, and the off-season with it: 10 June to 31 August.
    static let summerWindow = (open: 610, shut: 831)
    /// Winter window: 1 January to 2 February.
    static let winterWindow = (open: 101, shut: 202)
    /// A window's last three days are deadline days.
    static let deadlineDays = 3
    /// "New season" and "the run-in", by month.
    static let earlySeasonMonths: Set<Int> = [8, 9]
    static let runInMonths: Set<Int> = [4, 5]

    /// Month and day as one comparable number, the way the windows above are
    /// written. Both windows sit inside a calendar year, so this is enough.
    static func stamp(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    /// (window open, deadline days, it is the summer one).
    static func window(at date: Date) -> (open: Bool, deadline: Bool, summer: Bool) {
        let md = stamp(date)
        // The last three days of a window are "deadline day" territory.
        // Summer shuts on 31 August, so `shut - (deadlineDays - 1)` is a real
        // date there. Winter shuts on 2 February and 202 - 2 is not a date at
        // all, so its last three days (31 Jan, 1 and 2 Feb) are written out as
        // `md >= 131` — deliberately one day early, because deadline day in
        // January is the one everybody talks about.
        if md >= summerWindow.open, md <= summerWindow.shut {
            return (true, md > summerWindow.shut - deadlineDays, true)
        }
        if md >= winterWindow.open, md <= winterWindow.shut {
            return (true, md >= 131, false)
        }
        return (false, false, false)
    }
}

// MARK: - What weekend it is

/// The one thing on the Lingo landing screen that changes: what this weekend
/// is, derived on device from the team page His Team already caches.
///
/// Pure. Team page in, plus which club she follows and what time it is, and a
/// title, a subtitle and a priority-ordered list of tags out. No networking,
/// no store, no `Date()` of its own — everything comes through `now`, which is
/// what makes `LingoFixtures` and the self-check possible.
struct MatchContext: Equatable {
    enum Phase: Equatable {
        case before(opponent: String, kickoff: Date)
        case after(opponent: String, outcome: String?, teamScore: Int?, oppScore: Int?)
        case any
    }

    let phase: Phase
    /// Priority-ordered. The first one drives the subtitle and the deck's first
    /// pick; the last is always `any`.
    let tags: [String]
    let sixPointer: Bool
    /// Set by the view after `LingoWeekendDeck.build` reports that the deck
    /// fell back to words she already knows, because it changes the subtitle.
    var refresher: Bool = false
    /// Stable id for the fixture this context is about, for the deal seed: the
    /// same fixture deals the same seven until she asks for another.
    let fixtureKey: String

    let title: String
    /// Held without the refresher sentence so `refresher` can be flipped after
    /// the deck is built without rebuilding the context.
    private let baseSubtitle: String

    var subtitle: String {
        guard refresher else { return baseSubtitle }
        // Keep the first sentence (what weekend it is) and replace the promise
        // of seven new words, which would be a lie. A one-sentence subtitle is
        // nothing but that promise, so it goes whole — otherwise she gets two
        // promises in a row.
        let refresh = "You've got these already. 7 for a refresher."
        let sentences = baseSubtitle.split(separator: ".").count
        guard sentences > 1, let end = baseSubtitle.firstIndex(of: ".") else { return refresh }
        return String(baseSubtitle[...end]) + " " + refresh
    }

    /// The 19 tags content may carry. A `when` value outside this set never
    /// matches a context; the validator is what keeps content inside it.
    /// `new-manager` is inactive: nothing derives it any more (the generator
    /// always writes a manager summary), but content carrying it stays valid —
    /// a tag no context produces simply never matches.
    static let knownTags: Set<String> = [
        "any", "derby", "cup", "europe", "title", "top-four", "relegation",
        "good-run", "bad-run", "new-manager", "window", "early-season", "run-in",
        "after-win", "after-loss", "after-draw", "after-big-win",
        "after-heavy-loss", "after-clean-sheet",
    ]

    /// How long after kickoff a game still counts as "the game he is in".
    private static let inProgress: TimeInterval = 2 * 3600 + 15 * 60
    /// How long a result stays the thing worth having words for.
    private static let afterWindow: TimeInterval = 36 * 3600
    /// How far ahead a fixture is worth preparing for.
    private static let beforeWindow: TimeInterval = 21 * 24 * 3600
    /// Under this and the next game wins over the last result.
    private static let beforeBeatsAfter: TimeInterval = 24 * 3600

    // MARK: Derivation

    init(page: TeamPageContent?, team: Team?, now: Date) {
        let cards = page?.cards

        // --- The last result -------------------------------------------------
        // After-match state comes from the results list, not from the
        // `post_match` card. That card became club-wide on 2026-09-23 (it was
        // World-Cup-only when this was written), but the results list stays
        // the right source here: it carries the kickoff time, which is what
        // decides whether the result is still inside afterWindow, and it is
        // present whether or not match-watcher managed to write a card.
        let last = cards?.recentResults?.first
        let lastKickoff = last.flatMap { Self.parseISO($0.date) }
        let hasResult = lastKickoff.map { now.timeIntervalSince($0) >= 0 && now.timeIntervalSince($0) <= Self.afterWindow } ?? false

        // --- The next fixture ------------------------------------------------
        // `nextFixture` carries no status, so a postponed game can sit there
        // with a date that has quietly gone past. Cross-check the calendar.
        var nextOpponent = cards?.nextFixture?.opponent
        var nextKickoff = (cards?.nextFixture?.date).flatMap(Self.parseISO)
        var nextVenue = cards?.nextFixture?.venue
        var nextCompetition = cards?.nextFixture?.competitionShort
        var nextLeagueId = cards?.nextFixture?.leagueId
        var nextRound = cards?.nextFixture?.round
        // The soonest fixture the calendar still believes in, which is the only
        // list carrying a status.
        let live = (cards?.upcomingFixtures ?? [])
            .filter { !$0.isPostponed }
            .compactMap { f -> (UpcomingFixture, Date)? in Self.parseISO(f.date).map { (f, $0) } }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }
        if let opp = nextOpponent, let kick = nextKickoff,
           cards?.upcomingFixtures?.contains(where: {
               $0.isPostponed && Self.sameClub($0.opponent, opp)
                   && abs((Self.parseISO($0.date) ?? kick).timeIntervalSince(kick)) < 12 * 3600
           }) == true {
            nextOpponent = live?.0.opponent
            nextKickoff = live?.1
            nextVenue = live?.0.venue
            nextCompetition = nil
            nextLeagueId = live?.0.leagueId
            nextRound = nil
        }
        let hasFixture = nextKickoff.map {
            $0.timeIntervalSince(now) > -Self.inProgress && $0.timeIntervalSince(now) <= Self.beforeWindow
        } ?? false

        // --- Which one wins --------------------------------------------------
        enum Choice { case before, after, none }
        var choice: Choice = .none
        if hasFixture, hasResult {
            // A game in progress stays Before; so does anything inside a day.
            choice = (nextKickoff!.timeIntervalSince(now) < Self.beforeBeatsAfter) ? .before : .after
        } else if hasFixture {
            choice = .before
        } else if hasResult {
            choice = .after
        } else if let kick = nextKickoff, let opp = nextOpponent,
                  now.timeIntervalSince(kick) > Self.inProgress,
                  now.timeIntervalSince(kick) <= Self.afterWindow,
                  cards?.upcomingFixtures?.contains(where: {
                      !$0.isPostponed && Self.sameClub($0.opponent, opp)
                          && abs((Self.parseISO($0.date) ?? kick).timeIntervalSince(kick)) < 12 * 3600
                  }) == true {
            // Kickoff has passed, the calendar still says the game was on, and
            // no result has landed: it happened, the page has not caught up.
            // Post-mortem without a score.
            //
            // The calendar row is what makes this safe. A postponement whose
            // PST row has already aged out of `upcoming_fixtures` leaves a dead
            // date on `next_fixture`, and "Full-time against Chelsea" for a
            // game nobody played is worse than saying nothing.
            self.init(afterOpponent: opp, outcome: nil, teamScore: nil, oppScore: nil,
                      resultDate: kick, cards: cards, team: team, now: now)
            return
        } else if let next = live, next.1.timeIntervalSince(now) <= Self.beforeWindow {
            // Nothing to look back on, and `next_fixture` is a date that has
            // gone by. Prepare for the next game that is actually on.
            self.init(beforeOpponent: next.0.opponent, kickoff: next.1, venue: next.0.venue,
                      competition: nil, leagueId: next.0.leagueId, round: nil,
                      cards: cards, team: team, now: now)
            return
        }

        switch choice {
        case .before:
            self.init(beforeOpponent: nextOpponent!, kickoff: nextKickoff!, venue: nextVenue,
                      competition: nextCompetition, leagueId: nextLeagueId, round: nextRound,
                      cards: cards, team: team, now: now)
        case .after:
            self.init(afterOpponent: last!.opponent, outcome: last!.outcome,
                      teamScore: last!.teamScore, oppScore: last!.oppScore,
                      resultDate: lastKickoff!, cards: cards, team: team, now: now)
        case .none:
            self.init(anyAt: now)
        }
    }

    /// No club, no page, off-season, or nothing in range.
    private init(anyAt now: Date) {
        let w = LingoCalendar.window(at: now)
        // The summer window runs to 31 August, but the season is back in the
        // second week of August: "No football till August" through the opening
        // weekends is just wrong.
        let offSeason = w.summer && [6, 7].contains(Calendar.current.component(.month, from: now))
        phase = .any
        tags = (w.open ? ["window"] : []) + ["any"]
        sixPointer = false
        fixtureKey = "any"
        title = offSeason ? "Silly season" : "The first words"
        baseSubtitle = offSeason
            ? "No football till August. 7 words for the transfer window."
            : "7 words you'll hear at any match."
    }

    /// Before: the fixture, the table, the shape of the season.
    private init(beforeOpponent opponent: String, kickoff: Date, venue: String?,
                 competition: String?, leagueId: Int?, round: String?,
                 cards: TeamPageCards?, team: Team?, now: Date) {
        let opp = Self.shortName(opponent)
        let day = Self.dayLabel(kickoff, now: now)

        let derby = cards?.rivalry?.rival.map { Self.sameClub(opponent, $0) } ?? false
        let cup = [45, 48].contains(leagueId ?? 0) || (competition?.localizedCaseInsensitiveContains("Cup") ?? false)
        let europe = [2, 3, 848].contains(leagueId ?? 0)
            || ["Champions", "Europa", "Conference"].contains { competition?.localizedCaseInsensitiveContains($0) ?? false }

        let standing = Self.standing(cards: cards, team: team)
        let rank = standing.map(\.rank)
        let position = standing.flatMap { $0.played >= 10 ? Self.position($0.rank) : nil }
        let oppRank = cards?.standings?.entries.first { Self.sameClub($0.teamName, opponent) }?.rank
        var six = false
        if position == "title" || position == "relegation", let me = rank, let them = oppRank {
            six = abs(me - them) <= 3
        }

        let season = Self.seasonTags(cards: cards, now: now)
        var t: [String] = []
        if derby { t.append("derby") }
        if cup { t.append("cup") }
        if europe { t.append("europe") }
        if let position { t.append(position) }
        t += season.tags
        t.append("any")

        phase = .before(opponent: opponent, kickoff: kickoff)
        tags = t
        sixPointer = six
        fixtureKey = "b|\(opponent)|\(Self.dayStamp(kickoff))"
        title = "Before \(opp)"

        // Most specific first. Six-pointer beats the plain title line: "1st
        // against 2nd" says more than "1st in the table".
        if derby {
            baseSubtitle = "Derby week. 7 words you'll hear before \(day)."
        } else if cup, round?.contains("3rd") == true {
            baseSubtitle = "Third round \(day). 7 words for a cup weekend."
        } else if cup {
            baseSubtitle = "\(competition ?? "Cup tie") on \(day). 7 cup words before kick-off."
        } else if europe {
            baseSubtitle = "European night on \(day). 7 words for midweek football."
        } else if six, let me = rank, let them = oppRank {
            baseSubtitle = "\(LiveClubPack.ordinal(me)) against \(LiveClubPack.ordinal(them)). Proper six-pointer. 7 words for it."
        } else if position == "title", let me = rank {
            baseSubtitle = "\(LiveClubPack.ordinal(me)) in the table. 7 words for a title race."
        } else if position == "top-four", let me = rank {
            baseSubtitle = "\(LiveClubPack.ordinal(me)). 7 words for the race for the top four."
        } else if position == "relegation", let me = rank {
            baseSubtitle = "\(LiveClubPack.ordinal(me)). 7 words for the bottom of the table."
        } else if season.tags.first == "good-run" {
            baseSubtitle = "Three wins on the bounce. 7 words for a team in form."
        } else if season.tags.first == "bad-run" {
            baseSubtitle = "No win in five. Tense week. 7 words for \(day)."
        } else if season.deadline {
            baseSubtitle = "Deadline day. 7 words for a night of refreshing the phone."
        } else if season.tags.contains("window") {
            baseSubtitle = "Window's open. 7 words for the transfer chat before \(day)."
        } else if season.tags.contains("early-season") {
            baseSubtitle = "New season. 7 words for the first few weeks."
        } else if season.tags.contains("run-in") {
            baseSubtitle = "The run-in. 7 words for the games that decide it."
        } else {
            let where_ = (venue ?? "").lowercased() == "away" ? "Away at" : "Home to"
            baseSubtitle = "\(where_) \(opp) on \(day). 7 words you'll hear."
        }
    }

    /// After: the result, and the mood it left behind.
    private init(afterOpponent opponent: String, outcome: String?, teamScore: Int?, oppScore: Int?,
                 resultDate: Date, cards: TeamPageCards?, team: Team?, now: Date) {
        let opp = Self.shortName(opponent)
        let derby = cards?.rivalry?.rival.map { Self.sameClub(opponent, $0) } ?? false
        var margin = 0
        var score: String? = nil
        if let mine = teamScore, let theirs = oppScore {
            margin = abs(mine - theirs)
            score = "\(mine)-\(theirs)"
        }
        let won = outcome == "W", lost = outcome == "L", drew = outcome == "D"
        let cleanSheet = oppScore == 0 && (won || drew)

        var t: [String] = []
        if derby { t.append("derby") }
        if won, margin >= 3 { t.append("after-big-win") }
        if lost, margin >= 3 { t.append("after-heavy-loss") }
        if cleanSheet { t.append("after-clean-sheet") }
        if won { t.append("after-win") }
        if lost { t.append("after-loss") }
        if drew { t.append("after-draw") }
        let standing = Self.standing(cards: cards, team: team)
        if let position = standing.flatMap({ $0.played >= 10 ? Self.position($0.rank) : nil }) { t.append(position) }
        let season = Self.seasonTags(cards: cards, now: now)
        t += season.tags
        t.append("any")

        phase = .after(opponent: opponent, outcome: outcome, teamScore: teamScore, oppScore: oppScore)
        tags = t
        sixPointer = false
        fixtureKey = "a|\(opponent)|\(Self.dayStamp(resultDate))"
        title = "After \(opp)"

        if let score {
            if derby, lost {
                baseSubtitle = "They lost the derby \(score). 7 words. Pick your moment."
            } else if derby, won {
                baseSubtitle = "They won the derby \(score). 7 words for a very good week."
            } else if won, margin >= 3 {
                baseSubtitle = "They won \(score). 7 words for a very good mood."
            } else if won, cleanSheet {
                baseSubtitle = "\(score) and nothing let in. 7 words for a happy defence."
            } else if won {
                baseSubtitle = "They won \(score). 7 words for a good mood."
            } else if lost, margin >= 3 {
                baseSubtitle = "They lost \(score). 7 words. Tread carefully tonight."
            } else if lost {
                baseSubtitle = "They lost \(score). 7 words for the post-mortem."
            } else {
                baseSubtitle = "A \(score) draw. 7 words for a so-so afternoon."
            }
        } else {
            baseSubtitle = "Full-time against \(opp). 7 words for the post-mortem."
        }
    }

    // MARK: Pieces

    /// Her club's row in the league table, however the page names it.
    private static func standing(cards: TeamPageCards?, team: Team?) -> StandingsEntry? {
        guard let team, let entries = cards?.standings?.entries else { return nil }
        // The feed writes its own spelling ("Bournemouth", "Brighton"), which
        // is not `displayName` for seven of the twenty.
        return entries.first {
            $0.teamIdApiFootball == team.apiFootballId || Self.sameClub($0.teamName, team.displayName)
        }
    }

    /// Where a rank puts you, in tags. Nil in mid-table, which is not a story.
    private static func position(_ rank: Int) -> String? {
        switch rank {
        case ...0:   return nil
        case 1...3:  return "title"
        case 4...7:  return "top-four"
        case 16...:  return "relegation"
        default:     return nil
        }
    }

    /// Form, the dugout and the calendar: the tags that do not depend on which
    /// side of a match we are on.
    private static func seasonTags(cards: TeamPageCards?, now: Date) -> (tags: [String], deadline: Bool) {
        var t: [String] = []
        let results = (cards?.recentResults ?? []).prefix(3).map(\.outcome)
        let form = (cards?.form?.recentForm ?? "").uppercased().filter { "WDL".contains($0) }
        let lastThreeForm = String(form.suffix(3))
        let lastFiveForm = String(form.suffix(5))
        // The results list is the better source; `recentForm` is the fallback
        // for a page that has fewer than three of them, either way round.
        let enough = results.count == 3
        let goodRun = enough ? results.allSatisfy { $0 == "W" }
            : (lastThreeForm.count == 3 && lastThreeForm.allSatisfy { $0 == "W" })
        let badRun = enough ? !results.contains("W")
            : (lastFiveForm.count == 5 && !lastFiveForm.contains("W"))
        if goodRun { t.append("good-run") }
        if badRun { t.append("bad-run") }

        let w = LingoCalendar.window(at: now)
        if w.open { t.append("window") }
        let month = Calendar.current.component(.month, from: now)
        if LingoCalendar.earlySeasonMonths.contains(month) { t.append("early-season") }
        if LingoCalendar.runInMonths.contains(month) { t.append("run-in") }
        return (t, w.deadline)
    }

    // MARK: Club names

    /// Are these two strings the same club? API-Football says "Tottenham",
    /// `rivalry.rival` is hand-seeded "Tottenham Hotspur", and she says
    /// "Spurs". Nothing upstream gives us an id for either side.
    static func sameClub(_ a: String, _ b: String) -> Bool {
        guard !a.trimmingCharacters(in: .whitespaces).isEmpty,
              !b.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if let ta = exactTeam(a), let tb = exactTeam(b) { return ta == tb }
        guard let ka = clubKey(a), let kb = clubKey(b) else { return false }
        // The name minus its generic half has to match, whole: one side may be
        // shorter ("Brighton" for "Brighton and Hove Albion") but it may not
        // merely start the same way — "Nottingham Forest" is not "Forest Green
        // Rovers", and "West Ham" is not "West Bromwich Albion".
        let shorter = min(ka.core.count, kb.core.count)
        guard shorter > 0, Array(ka.core.prefix(shorter)) == Array(kb.core.prefix(shorter)) else { return false }
        // "Manchester United" and "Manchester City" share a core, so do
        // "Sheffield United" and "Sheffield Wednesday". Two clubs that each
        // carry a suffix must carry the same one.
        if ka.suffixes.isEmpty || kb.suffixes.isEmpty { return true }
        return !ka.suffixes.isDisjoint(with: kb.suffixes)
    }

    /// A club name for a title: `Team.shortName` when we can work out who it
    /// is ("Tottenham" → "Spurs"), the name as given when we cannot.
    static func shortName(_ name: String) -> String {
        let exact = LiveClubPack.clubShort(name)
        if exact != name { return exact }
        return Team.allCases.first { sameClub(name, $0.displayName) }?.shortName ?? name
    }

    private static func exactTeam(_ name: String) -> Team? {
        Team.allCases.first {
            $0.displayName.caseInsensitiveCompare(name) == .orderedSame
                || $0.shortName.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Words that are a club's second half, never its name: "Leeds United" and
    /// "Leeds" are one club, "United" on its own is nobody. "Wednesday" is in
    /// here for the same reason "United" is — it is what tells two Sheffields
    /// apart, and it is never a club on its own.
    private static let genericTokens: Set<String> = [
        "united", "city", "town", "hotspur", "albion", "wanderers", "athletic",
        "county", "rovers", "wednesday",
    ]

    /// Neither a name nor a suffix that tells two clubs apart.
    private static let noiseTokens: Set<String> = ["fc", "afc", "and"]

    /// What she and the commentary call them, mapped onto what the feed does.
    /// Applied to a whole name only, never token by token: "forest" on its own
    /// is Nottingham Forest, but the "forest" in "Forest Green Rovers" is not.
    private static let aliases: [String: String] = [
        "spurs": "tottenham hotspur", "wolves": "wolverhampton wanderers",
        "villa": "aston villa", "palace": "crystal palace",
        "forest": "nottingham forest", "nott'm forest": "nottingham forest",
        "man utd": "manchester united", "man united": "manchester united",
        "man city": "manchester city",
    ]

    /// The club's own words, and the generic ones it carries alongside them.
    private static func clubKey(_ name: String) -> (core: [String], suffixes: Set<String>)? {
        var s = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                             locale: Locale(identifier: "en")).lowercased()
            .trimmingCharacters(in: .whitespaces)
        if let whole = aliases[s] { s = whole }
        s = s.replacingOccurrences(of: "&", with: " and ")
        s = String(s.map { $0.isLetter || $0.isNumber ? $0 : " " })
        let tokens = s.split(separator: " ").map(String.init).filter { !noiseTokens.contains($0) }
        let core = tokens.filter { !genericTokens.contains($0) }
        guard !core.isEmpty else { return nil }
        return (core, Set(tokens.filter { genericTokens.contains($0) }))
    }

    // MARK: Dates

    /// The routine writes ISO 8601 with or without fractional seconds. Copied
    /// from `TeamPageView` rather than shared: one date parser is not worth a
    /// refactor across two files that will never disagree.
    static func parseISO(_ raw: String) -> Date? {
        isoFormatter.date(from: raw) ?? isoFractionalFormatter.date(from: raw)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// English kickoff days in English football time, whatever the phone is
    /// set to: `Locale.current` turns "Saturday" into "lördag" for a Swedish
    /// phone in London, and a 20:00 Saturday kickoff into Sunday in Tokyo.
    private static func labelFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }

    private static let weekdayFormatter = labelFormatter("EEEE")
    private static let dayMonthFormatter = labelFormatter("d MMMM")

    /// "Saturday" inside the week, "14 October" beyond it.
    private static func dayLabel(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                      to: cal.startOfDay(for: date)).day ?? 0
        return days < 6 ? weekdayFormatter.string(from: date) : dayMonthFormatter.string(from: date)
    }

    /// Local calendar day, for a fixture key that does not move when a kickoff
    /// time is nudged by fifteen minutes for the telly.
    private static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

// MARK: - This weekend's seven

/// Which seven words she gets, and the three options on each of them.
enum LingoWeekendDeck {
    /// Unchanged from the flashcard deck, so every word she has already marked
    /// known carries over.
    static let deckId = "lingo"
    static let roundLength = 7
    /// The one word a six-pointer is about. Forced into the deck when the
    /// fixture is one, because it is the phrase she will hear all week.
    static let sixPointerTermId = "six-pointer"

    /// The seven, easiest first, and whether they had to be padded out with
    /// words she already knows.
    ///
    /// Relevance decides *which* seven (her fixture's tag first, then any
    /// active tag, then words for any match) and which come first; difficulty
    /// orders them inside each of those three groups.
    static func build(terms: [LingoTerm], known: Set<String>, learning: Set<String>,
                      context: MatchContext?, seed: String) -> (ids: [String], refresher: Bool) {
        // `basic` words stay in the list and in search but never get dealt: the
        // first round on a fresh install fills from `any` sorted by level, and
        // asking a grown woman what "kick-off" means at the moment she is
        // deciding whether to keep the app is the app talking down to her.
        let playable = terms.filter { $0.basic != true && options(for: $0) != nil }
        guard !playable.isEmpty else { return ([], false) }

        let top = terms.compactMap(\.level).max() ?? 1
        func level(_ t: LingoTerm) -> Int { t.level ?? top }

        // One draw per term from the round seed, so the same seed deals the
        // same seven (reopening the tab) and a new nonce deals another
        // ("Go again"). Foundation's hashValue is per-process randomised.
        var draw: [String: UInt64] = [:]
        for t in playable {
            var rng = LiveClubPack.SeededGenerator(seed: seed + "|" + t.id)
            draw[t.id] = rng.next()
        }
        // Learning before new: the ones she got wrong last time come back.
        func key(_ t: LingoTerm) -> (Int, Int, UInt64) {
            (level(t), learning.contains(t.id) ? 0 : 1, draw[t.id] ?? 0)
        }

        var picked: [String] = []
        var seen: Set<String> = []
        // Why each word is in the deck: 0 this weekend's, 1 a word for any
        // match, 2 one she already knows. The deck is ordered by this first,
        // so a hard word about the actual fixture is not buried behind three
        // easy generic ones.
        var block: [String: Int] = [:]
        var current = 0
        func take(_ ts: [LingoTerm]) {
            for t in ts.sorted(by: { key($0) < key($1) }) where picked.count < roundLength {
                if seen.insert(t.id).inserted { picked.append(t.id); block[t.id] = current }
            }
        }

        let unknown = playable.filter { !known.contains($0.id) }
        if let context {
            let active = context.tags.filter { $0 != "any" }
            if context.sixPointer, let sp = unknown.first(where: { $0.id == sixPointerTermId }) { take([sp]) }
            if let primary = active.first { take(unknown.filter { ($0.when ?? []).contains(primary) }) }
            let activeSet = Set(active)
            take(unknown.filter { !Set($0.when ?? []).isDisjoint(with: activeSet) })
            current = 1
            take(unknown.filter { ($0.when ?? []).contains("any") })
        }
        current = 1
        take(unknown)

        // Never fewer than seven while seven playable words exist: a short
        // round reads as a bug, and a refresher is a real thing to offer.
        current = 2
        if picked.count < roundLength {
            let knownTerms = playable.filter { known.contains($0.id) }
            if let context {
                let allow = Set(context.tags)
                take(knownTerms.filter { !Set($0.when ?? []).isDisjoint(with: allow) })
            }
            take(knownTerms)
        }
        // Only call it a refresher when it mostly is one: six new words and one
        // she has seen before is still a week's worth of new words.
        let repeats = picked.filter { known.contains($0) }.count
        let refresher = repeats * 2 > picked.count

        let byId = Dictionary(playable.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func order(_ t: LingoTerm) -> (Int, Int, UInt64) { (block[t.id] ?? 1, level(t), draw[t.id] ?? 0) }
        let dealt = picked.compactMap { byId[$0] }.sorted { order($0) < order($1) }
        return (dealt.map(\.id), refresher)
    }

    /// The three options for a word, and which one is right. Nil when the word
    /// has not been written for Overheard yet, which is how an older cached
    /// lingo.json keeps working: it simply deals nothing.
    ///
    /// Seeded from the term id plus the dealing session's `salt`, so the order
    /// is fixed for the life of one dealt card — a paused round resumed, or
    /// relaunched, shows the right answer in the same slot — while the next
    /// deal of the same word reshuffles. Seeding from the id alone made every
    /// repeat an identical card, and the deck prefers words she missed, so the
    /// repeat is the common case and it degrades into thumb-position memory.
    ///
    /// An empty salt is the pre-2026-09-23 order, which is what a session
    /// persisted before the salt existed should keep showing.
    static func options(for term: LingoTerm, salt: String = "") -> (options: [String], answer: Int)? {
        // The snippet is the question. A word with a gist and two decoys but no
        // line to overhear would ask "what does that mean?" above the drier
        // `heard` note, which is a definition quiz again.
        guard term.overheard?.isEmpty == false,
              let gist = term.gist?.trimmingCharacters(in: .whitespacesAndNewlines), !gist.isEmpty,
              let decoys = term.decoys?.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                  .filter({ !$0.isEmpty }), decoys.count >= 2 else { return nil }
        var options = [gist] + decoys.prefix(2)
        guard Set(options).count == 3 else { return nil }
        var rng = LiveClubPack.SeededGenerator(seed: term.id + salt)
        options.shuffle(using: &rng)
        guard let answer = options.firstIndex(of: gist) else { return nil }
        return (options, answer)
    }

    /// The deal seed. Same club, same fixture, same day, same nonce gives the
    /// same seven; "Go again" bumps the nonce.
    static func seed(team: Team?, context: MatchContext?, now: Date, nonce: Int) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let state: String
        switch context?.phase {
        case .some(.before): state = "before"
        case .some(.after):  state = "after"
        case .some(.any):    state = "any"
        case .none:          state = "anywhere"
        }
        return [team?.rawValue ?? "none", state, context?.fixtureKey ?? "-",
                "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)", "\(nonce)"].joined(separator: "|")
    }
}

// MARK: - Levels

extension LingoContent {
    /// A file written before levels existed decodes with `level == nil`;
    /// treat those as the last level so they sort after everything placed.
    var topLevel: Int { terms.compactMap(\.level).max() ?? 1 }

    func level(of term: LingoTerm) -> Int { term.level ?? topLevel }
}

#if DEBUG
// MARK: - Fixtures for the self-check

/// Team pages as JSON, so the self-check exercises the real decoder rather
/// than a hand-built struct the decoder would never produce.
enum LingoFixtures {
    static func page(_ name: String, now: Date) -> TeamPageContent? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        func at(_ interval: TimeInterval) -> String { f.string(from: now.addingTimeInterval(interval)) }
        let day: TimeInterval = 24 * 3600

        let json: String
        switch name {
        case "derby":
            json = """
            {"schema_version":1,"cards":{
              "next_fixture":{"opponent":"Tottenham","date":"\(at(3 * day))","venue":"home","league_id":39},
              "rivalry":{"text":"The north London derby.","rival":"Tottenham Hotspur"}
            }}
            """
        case "cup":
            json = """
            {"schema_version":1,"cards":{
              "next_fixture":{"opponent":"Everton","date":"\(at(2 * day))","venue":"away",
                              "competition":"League Cup (Carabao Cup), 3rd Round","league_id":48,"round":"3rd Round"},
              "rivalry":{"text":"The north London derby.","rival":"Tottenham Hotspur"}
            }}
            """
        case "after-win":
            json = """
            {"schema_version":1,"cards":{
              "next_fixture":{"opponent":"Brighton","date":"\(at(10 * day))","venue":"home","league_id":39},
              "recent_results":[{"date":"\(at(-3 * 3600))","opponent":"Everton","venue":"home","team_score":3,"opp_score":0}]
            }}
            """
        case "after-loss":
            json = """
            {"schema_version":1,"cards":{
              "next_fixture":{"opponent":"Brighton","date":"\(at(10 * day))","venue":"home","league_id":39},
              "recent_results":[{"date":"\(at(-5 * 3600))","opponent":"Everton","venue":"away","team_score":1,"opp_score":2}]
            }}
            """
        case "postponed":
            json = """
            {"schema_version":1,"cards":{
              "next_fixture":{"opponent":"Chelsea","date":"\(at(2 * day))","venue":"home","league_id":39},
              "upcoming_fixtures":[
                {"date":"\(at(2 * day))","opponent":"Chelsea","venue":"home","importance_dots":4,
                 "importance_label":"Postponed","status":"PST","league_id":39},
                {"date":"\(at(9 * day))","opponent":"Fulham","venue":"away","importance_dots":2,
                 "importance_label":"A winnable one","status":"NS","league_id":39}]
            }}
            """
        case "phantom":
            // The same postponement three hours later: `fixture-rollover` has
            // dropped the PST row, `next_fixture` still holds the dead date.
            json = """
            {"schema_version":1,"cards":{
              "next_fixture":{"opponent":"Chelsea","date":"\(at(-4 * 3600))","venue":"home","league_id":39},
              "upcoming_fixtures":[
                {"date":"\(at(6 * day))","opponent":"Fulham","venue":"away","importance_dots":2,
                 "importance_label":"A winnable one","status":"NS","league_id":39}]
            }}
            """
        default:
            return nil
        }
        return try? JSONDecoder().decode(TeamPageContent.self, from: Data(json.utf8))
    }
}

// MARK: - Self-check

/// The runnable check this module leaves behind, in place of the XCTest target
/// the project does not have. Fired once from Lingo's `onAppear` in DEBUG.
///
/// What it is really guarding: a wrong `sameClub` silently mislabels every
/// derby weekend, and a non-deterministic deck or option order means a paused
/// round comes back with a different right answer under her finger.
@MainActor
func lingoDeckSelfCheck(bundled: LingoContent) {
    // A fixed instant so the calendar tags are the same on every run: a
    // Saturday in October, no transfer window, no early season, no run-in.
    let now = MatchContext.parseISO("2026-10-17T12:00:00Z")!

    // --- Club names ------------------------------------------------------
    // Every rival seeded by migration 091, against the spelling API-Football
    // sends for the same club: this is the pair that decides whether a derby
    // weekend is labelled one, and nothing upstream gives either side an id.
    for (feed, seeded) in [
        ("Tottenham", "Tottenham Hotspur"), ("Birmingham", "Birmingham City"),
        ("Southampton", "Southampton"), ("Fulham", "Fulham"),
        ("Crystal Palace", "Crystal Palace"), ("Brighton", "Brighton & Hove Albion"),
        ("Liverpool", "Liverpool"), ("Chelsea", "Chelsea"),
        ("Leeds", "Leeds United"), ("Norwich", "Norwich City"),
        ("Manchester United", "Manchester United"), ("Sunderland", "Sunderland"),
        ("Derby", "Derby County"), ("Arsenal", "Arsenal"),
        ("Newcastle", "Newcastle United"), ("Bournemouth", "AFC Bournemouth"),
        ("Man Utd", "Manchester United"), ("Spurs", "Tottenham Hotspur"),
        ("Wolves", "Wolverhampton Wanderers"), ("West Ham", "West Ham United"),
    ] {
        assert(MatchContext.sameClub(feed, seeded), "sameClub missed \(feed) / \(seeded)")
    }
    // Clubs that share a word and are not the same club.
    for (a, b) in [
        ("Nottingham Forest", "Forest Green Rovers"), ("Sheffield United", "Sheffield Wednesday"),
        ("West Ham", "West Bromwich Albion"), ("Real Madrid", "Real Sociedad"),
        ("Manchester United", "Manchester City"), ("Arsenal", "Aston Villa"),
        ("", "Arsenal"),
    ] {
        assert(!MatchContext.sameClub(a, b), "sameClub matched \(a) / \(b)")
    }
    assert(MatchContext.shortName("Forest Green Rovers") != "Nott'm Forest",
           "shortName turned a non-league club into Nottingham Forest")

    // --- Context ---------------------------------------------------------
    let derby = MatchContext(page: LingoFixtures.page("derby", now: now), team: .arsenal, now: now)
    if case .before = derby.phase {} else { assertionFailure("a fixture three days out is not Before") }
    assert(derby.tags.first == "derby", "the derby tag is not leading: \(derby.tags)")
    assert(derby.title == "Before Spurs", "derby title was \(derby.title)")
    assert(derby.tags.last == "any", "tags must end with any")

    let cup = MatchContext(page: LingoFixtures.page("cup", now: now), team: .arsenal, now: now)
    assert(cup.tags.first == "cup", "a League Cup tie is not tagged cup: \(cup.tags)")

    let loss = MatchContext(page: LingoFixtures.page("after-loss", now: now), team: .arsenal, now: now)
    if case .after = loss.phase {} else { assertionFailure("a result five hours old is not After") }
    assert(loss.tags.contains("after-loss") && !loss.tags.contains("after-win"),
           "after-loss tags were \(loss.tags)")

    let win = MatchContext(page: LingoFixtures.page("after-win", now: now), team: .arsenal, now: now)
    assert(win.tags.contains("after-win") && win.tags.contains("after-big-win")
           && win.tags.contains("after-clean-sheet"), "a 3-0 win was tagged \(win.tags)")

    let pst = MatchContext(page: LingoFixtures.page("postponed", now: now), team: .arsenal, now: now)
    if case .before(let opponent, _) = pst.phase {
        assert(MatchContext.sameClub(opponent, "Fulham"), "a postponed game was not skipped: \(opponent)")
    } else {
        assertionFailure("the postponed fixture left no Before context")
    }

    // The same postponement once its PST row has aged out: a dead date on
    // `next_fixture` must never become "Full-time against Chelsea".
    let phantom = MatchContext(page: LingoFixtures.page("phantom", now: now), team: .arsenal, now: now)
    if case .after(let opponent, _, _, _) = phantom.phase {
        assertionFailure("a game that was never played got a post-mortem: \(opponent)")
    }
    if case .before(let opponent, _) = phantom.phase {
        assert(MatchContext.sameClub(opponent, "Fulham"), "the dead date was not skipped: \(opponent)")
    }

    let none = MatchContext(page: nil, team: .arsenal, now: now)
    assert(none.phase == .any && none.tags == ["any"], "no page should be the any context")

    // --- The deck --------------------------------------------------------
    func term(_ id: String, level: Int, when: [String]) -> LingoTerm {
        LingoTerm(id: id, category: .matchSituations, term: id, meaning: "m", heard: "h",
                  sayIt: nil, seeAlso: nil, level: level,
                  overheard: "They said \(id).", overheardTerm: id, speaker: .him,
                  gist: "gist \(id)", decoys: ["decoy one \(id)", "decoy two \(id)"], when: when,
                  basic: nil)
    }
    // The derby words sit ABOVE the fillers by difficulty, so "derby first" is
    // a statement about selection and about relevance beating level — with
    // them at level 1 the assertion passes even with tag selection deleted.
    var synthetic = (0..<4).map { term("derby-\($0)", level: 3, when: ["derby", "any"]) }
    synthetic += (0..<6).map { term("any-\($0)", level: 1, when: ["any"]) }
    synthetic += (0..<4).map { term("cup-\($0)", level: 2, when: ["cup"]) }

    let dealt = LingoWeekendDeck.build(terms: synthetic, known: [], learning: [],
                                       context: derby, seed: "s1")
    assert(dealt.ids.count == LingoWeekendDeck.roundLength, "deck dealt \(dealt.ids.count)")
    assert(Set(dealt.ids).count == dealt.ids.count, "deck repeated a word")
    assert(dealt.ids.prefix(4).allSatisfy { $0.hasPrefix("derby-") },
           "the derby words did not come first, so relevance lost to level: \(dealt.ids)")
    assert(!dealt.refresher, "a deck of fourteen unknown words is not a refresher")
    let levels = dealt.ids.compactMap { id in synthetic.first { $0.id == id }?.level ?? 0 }
    assert(Array(levels.prefix(4)) == Array(levels.prefix(4)).sorted()
           && Array(levels.dropFirst(4)) == Array(levels.dropFirst(4)).sorted(),
           "the deck is not easiest first inside its relevance blocks: \(levels)")

    let again = LingoWeekendDeck.build(terms: synthetic, known: [], learning: [],
                                       context: derby, seed: "s1")
    assert(again.ids == dealt.ids, "the same seed dealt a different seven")
    // "Go again" has to be able to deal something else. Two seeds landing on
    // the same three fillers out of six is a coincidence, not a bug, so this
    // asks whether ANY of a handful of seeds differ.
    let variants = Set((1...8).map {
        LingoWeekendDeck.build(terms: synthetic, known: [], learning: [],
                               context: derby, seed: "n\($0)").ids
    })
    assert(variants.count > 1, "every seed dealt exactly the same seven")

    let allKnown = LingoWeekendDeck.build(terms: synthetic, known: Set(synthetic.map(\.id)),
                                          learning: [], context: derby, seed: "s1")
    assert(allKnown.ids.count == LingoWeekendDeck.roundLength && allKnown.refresher,
           "every word known should still deal seven, as a refresher")

    // One padded word out of seven is not "you've got these already".
    let mostlyNew = LingoWeekendDeck.build(
        terms: synthetic, known: Set(synthetic.map(\.id)).subtracting(synthetic.prefix(6).map(\.id)),
        learning: [], context: derby, seed: "s1")
    assert(mostlyNew.ids.count == LingoWeekendDeck.roundLength && !mostlyNew.refresher,
           "six new words and one known is not a refresher")

    // Tags against levels: two cup words buried at level 5 behind eight easy
    // ones. A cup context has to reach past the levels for them; "or seven
    // from anywhere" has to ignore the tags and take the easy eight.
    let buried = (0..<8).map { term("plain-\($0)", level: 1, when: ["any"]) }
        + (0..<2).map { term("deep-cup-\($0)", level: 5, when: ["cup"]) }
    let cupDeck = LingoWeekendDeck.build(terms: buried, known: [], learning: [], context: cup, seed: "s1")
    assert(cupDeck.ids.prefix(2).allSatisfy { $0.hasPrefix("deep-cup-") },
           "the cup context did not reach past the levels for its words: \(cupDeck.ids)")
    let anywhere = LingoWeekendDeck.build(terms: buried, known: [], learning: [], context: nil, seed: "s1")
    assert(anywhere.ids.count == LingoWeekendDeck.roundLength, "a deck from anywhere is still seven")
    assert(!anywhere.ids.contains { $0.hasPrefix("deep-cup-") },
           "nil context should ignore the tags: \(anywhere.ids)")

    let three = LingoWeekendDeck.build(terms: Array(synthetic.prefix(3)), known: [], learning: [],
                                       context: derby, seed: "s1")
    assert(three.ids.count == 3, "three playable words should deal three, not pad")

    // --- The options -----------------------------------------------------
    let playable = term("opt", level: 1, when: ["any"])
    guard let first = LingoWeekendDeck.options(for: playable),
          let second = LingoWeekendDeck.options(for: playable) else {
        assertionFailure("a word with a gist and two decoys is not playable")
        return
    }
    assert(first.options == second.options && first.answer == second.answer,
           "option order is not deterministic, so a paused round moves the right answer")
    assert(first.options[first.answer] == playable.gist, "the answer index does not point at the gist")
    assert(first.options.count == 3, "an Overheard card is three options")

    // The salt. One session's salt has to be stable — she pauses a round, the
    // app is relaunched, the right answer must still be under the same
    // option — and two sessions have to disagree, or every repeat of a word
    // she missed is the same card and the round tests her thumb.
    let salted = LingoWeekendDeck.options(for: playable, salt: "session-a")
    let saltedAgain = LingoWeekendDeck.options(for: playable, salt: "session-a")
    assert(salted?.options == saltedAgain?.options && salted?.answer == saltedAgain?.answer,
           "the same salt gave a different order, so a resumed round moves the right answer")
    assert(salted?.options[salted!.answer] == playable.gist, "a salted answer index does not point at the gist")
    // A single word can land the same way under two salts (one order in six),
    // so this asks over a sample rather than of one term.
    let sample = (0..<10).map { term("salt-\($0)", level: 1, when: ["any"]) }
    assert(sample.contains { t in
        LingoWeekendDeck.options(for: t, salt: "session-a")?.options
            != LingoWeekendDeck.options(for: t, salt: "session-b")?.options
    }, "two different salts dealt every word in the same order, so the salt does nothing")
    let bare = LingoTerm(id: "bare", category: .rules, term: "Bare", meaning: "m", heard: "h",
                         sayIt: nil, seeAlso: nil, level: 1, overheard: nil, overheardTerm: nil,
                         speaker: nil, gist: nil, decoys: nil, when: nil, basic: nil)
    assert(LingoWeekendDeck.options(for: bare) == nil, "a word with no decoys must not be playable")
    let noSnippet = LingoTerm(id: "no-snippet", category: .rules, term: "Nosnip", meaning: "m",
                              heard: "h", sayIt: nil, seeAlso: nil, level: 1, overheard: nil,
                              overheardTerm: nil, speaker: .him, gist: "gist nosnip",
                              decoys: ["decoy one", "decoy two"], when: ["any"], basic: nil)
    assert(LingoWeekendDeck.options(for: noSnippet) == nil,
           "a word with options but no line to overhear must not be playable")

    // --- The bundled content ---------------------------------------------
    // Against the copy in the app bundle, not against `bundled`: that is
    // whatever `MyTurnContentService` loaded, which may be a newer downloaded
    // file carrying a tag this build has never heard of — which is the model's
    // contract working (an unmatched tag simply never fires), not a bug.
    let shipped = (Bundle.main.url(forResource: "lingo", withExtension: "json", subdirectory: "MyTurn")
        ?? Bundle.main.url(forResource: "lingo", withExtension: "json"))
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? JSONDecoder().decode(LingoContent.self, from: $0) }
    let live = (shipped ?? bundled).terms
    for t in live {
        for tag in t.when ?? [] {
            assert(MatchContext.knownTags.contains(tag),
                   "lingo.json term \(t.id) carries an unknown when tag: \(tag)")
        }
    }

    // The first round on a fresh install: no cached team page, so the `any`
    // context, and the deck fills from `any` sorted by level. Nothing she can
    // read off the word itself may be in it, and it still has to be seven —
    // marking too many words basic would empty the pool instead.
    let basicIds = Set(live.filter { $0.basic == true }.map(\.id))
    let firstRound = LingoWeekendDeck.build(terms: live, known: [], learning: [], context: none,
                                            seed: LingoWeekendDeck.seed(team: nil, context: none,
                                                                        now: now, nonce: 0))
    assert(firstRound.ids.count == LingoWeekendDeck.roundLength,
           "the first round on a fresh install deals \(firstRound.ids.count), not seven")
    assert(Set(firstRound.ids).isDisjoint(with: basicIds),
           "the first round asks what a word she can read means: \(Set(firstRound.ids).intersection(basicIds))")
}
#endif
