import EventKit
import Foundation

/// One-way sync of his teams' fixtures into the user's iOS calendar.
///
/// Each followed entity (his WC country AND his PL club) gets a dedicated
/// "GoalDigger - <team>" calendar so the user can hide or delete them in one
/// move. `resync` reconciles those calendars against whoever is currently
/// followed: it refreshes each followed entity's games from the authoritative
/// fixture source and removes calendars for entities no longer followed. It is
/// called on every launch/foreground (when enabled), so new games appear and
/// finished games disappear without the user lifting a finger.
@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()
    private let store = EKEventStore()
    private let titlePrefix = "GoalDigger - "
    /// Throttles the launch/foreground auto-resync so a user toggling between
    /// apps doesn't trigger a fixture fetch every few seconds.
    private var lastAutoResyncAt: Date?

    enum SyncError: LocalizedError {
        case denied
        case noWritableSource
        var errorDescription: String? {
            switch self {
            case .denied: return "Calendar access denied"
            case .noWritableSource: return "No writable calendar source available"
            }
        }
    }

    /// Prompts for calendar access if not already determined.
    /// Returns true if access is granted.
    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    /// Reconcile the user's GoalDigger calendars against the entities he
    /// currently follows (WC country first, then PL club). For each followed
    /// entity we refresh its calendar from the authoritative fixture source
    /// (wiping past AND future events, then adding the upcoming games).
    /// Calendars for entities no longer followed are removed.
    ///
    /// Safety: an entity whose fixtures can't be fetched (network failure) is
    /// LEFT UNTOUCHED this round, never wiped, so a flaky connection can't
    /// silently empty the user's calendar. Caller must already hold access.
    func resync(teams: [Team], countries: [Country]) async throws {
        // Fresh view of the store: this long-lived EKEventStore otherwise holds
        // a stale snapshot after the user edits/deletes calendars outside the
        // app (the old "added once, deleted, won't re-add" bug).
        store.reset()

        // V2.2: sync the union of every followed country + club. Calendars for
        // entities no longer followed are pruned in step 1 below.
        let followed: [(shortName: String, teamId: String)] =
            countries.map { (shortName: $0.shortName, teamId: $0.rawValue) } +
            teams.map { (shortName: $0.shortName, teamId: $0.rawValue) }
        let followedTitles = Set(followed.map { calendarTitle($0.shortName) })

        // 1. Remove calendars for entities the user no longer follows (e.g. an
        //    old club after a team switch). Derived purely from app state, so
        //    it's safe regardless of network.
        for c in store.calendars(for: .event)
        where c.title.hasPrefix(titlePrefix) && !followedTitles.contains(c.title) {
            try? store.removeCalendar(c, commit: false)
        }
        try store.commit()

        // 2. Refresh each followed entity from authoritative fixtures. Each one
        //    stands alone: an unwritable country calendar used to throw out of
        //    the loop and his club never got its games.
        for entity in followed {
            let alreadySynced = existingCalendar(entity.shortName)
                .map { !store.events(matching: fullWindowPredicate($0)).isEmpty } ?? false
            guard let fixtures = await Self.loadFixtures(teamId: entity.teamId,
                                                        hasSyncedEvents: alreadySynced) else {
                continue // fetch failed — leave existing events intact this round
            }
            do {
                try writeCalendar(shortName: entity.shortName, fixtures: fixtures)
            } catch {
                continue
            }
        }
    }

    /// Launch / foreground hook: best-effort, non-prompting, throttled. No-op
    /// unless the user enabled sync AND already granted full calendar access
    /// (we never trigger the permission prompt from a background-resume path).
    func autoResync(teams: [Team], countries: [Country], enabled: Bool) async {
        guard enabled else { return }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        if let last = lastAutoResyncAt, Date().timeIntervalSince(last) < 30 * 60 { return }
        lastAutoResyncAt = Date() // set before awaiting so a rapid re-entry no-ops
        try? await resync(teams: teams, countries: countries)
    }

    /// Remove every "GoalDigger - *" calendar from the store (toggle-off).
    func removeAllGoalDiggerCalendars() throws {
        store.reset() // fresh view, so we see (and remove) the real current set
        for c in store.calendars(for: .event) where c.title.hasPrefix(titlePrefix) {
            try store.removeCalendar(c, commit: false)
        }
        try store.commit()
    }

    // MARK: - Internals

    private func calendarTitle(_ shortName: String) -> String { "\(titlePrefix)\(shortName)" }

    /// Wipe ALL events (past AND future) in this entity's calendar, then insert
    /// every upcoming fixture. Wiping the past too is what clears the stale,
    /// finished games the old future-only wipe left stranded in the calendar.
    private func writeCalendar(shortName: String, fixtures: [GDFixture]) throws {
        let calendar = try findOrCreateCalendar(title: calendarTitle(shortName))

        // Build the new events first, then swap the whole calendar in ONE
        // commit. The old order committed the deletes on their own, so a single
        // failing insert left her looking at an empty calendar.
        let newEvents: [EKEvent] = fixtures.map { fixture in
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            // Encode home/away into the title rather than event.location:
            // `fixture.venue` is just the literal "home"/"away" enum (no stadium
            // name), so the Location field would surface "home"/"away" as the
            // event location, which is confusing in iOS Calendar.
            // The competition earns its place in a calendar title: an entry
            // that just says "Sunderland vs Hull City (H)" gives no clue it is
            // a cup night.
            let competition = fixture.competition.map { " · \($0)" } ?? ""
            event.title = "\(shortName) vs \(fixture.opponent)\(venueSuffix(fixture.venue))\(competition)"
            event.startDate = fixture.kickoffTime
            event.endDate = fixture.kickoffTime.addingTimeInterval(2 * 60 * 60)
            // Without an explicit zone EventKit files the event in the calendar's
            // default zone, so a kickoff shifted by an hour after travel.
            event.timeZone = TimeZone.current
            event.notes = "Match day. Open GoalDigger for prep."
            return event
        }

        do {
            for event in store.events(matching: fullWindowPredicate(calendar)) {
                try? store.remove(event, span: .thisEvent, commit: false)
            }
            for event in newEvents {
                // Propagate save failures (a silent failure here is exactly the
                // "it doesn't add" symptom).
                try store.save(event, span: .thisEvent, commit: false)
            }
            try store.commit()
        } catch {
            store.reset() // drop the pending deletes; she keeps the games she had
            throw error
        }
    }

    private func existingCalendar(_ shortName: String) -> EKCalendar? {
        store.calendars(for: .event).first { $0.title == calendarTitle(shortName) }
    }

    /// Everything we could ever have written into one of our calendars: a year
    /// either side of now. Wiping the past too is what clears the stale,
    /// finished games the old future-only wipe left stranded.
    private func fullWindowPredicate(_ calendar: EKCalendar) -> NSPredicate {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        let end = cal.date(byAdding: .year, value: 1, to: now) ?? now
        return store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
    }

    private func venueSuffix(_ venue: String?) -> String {
        guard let v = venue?.lowercased() else { return "" }
        if v == "home" { return " (Home)" }
        if v == "away" { return " (Away)" }
        return ""
    }

    private func findOrCreateCalendar(title: String) throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == title }) {
            return existing
        }
        guard let source = writableSource() else {
            throw SyncError.noWritableSource
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = title
        cal.source = source
        try store.saveCalendar(cal, commit: true)
        return cal
    }

    /// Pick a source we can actually create a calendar in. `defaultCalendar
    /// ForNewEvents?.source` is nil on devices with no default calendar (and
    /// can point at a read-only subscribed source), which made the very first
    /// "add" fail with noWritableSource. Fall back to iCloud (CalDAV), then the
    /// on-device Local source, then any source that already holds a writable
    /// event calendar.
    private func writableSource() -> EKSource? {
        if let s = store.defaultCalendarForNewEvents?.source { return s }
        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            return icloud
        }
        if let local = store.sources.first(where: { $0.sourceType == .local }) { return local }
        if let anyCalDAV = store.sources.first(where: { $0.sourceType == .calDAV }) { return anyCalDAV }
        return store.sources.first { src in
            src.calendars(for: .event).contains { $0.allowsContentModifications }
        }
    }

    /// Authoritative upcoming fixtures for one entity (club or country): the
    /// team page's `upcoming_fixtures`, else its singular `next_fixture`.
    ///
    /// `team_season_state.next_fixtures` used to be tried first. Nothing has
    /// written that column since May 2026, and it carries neither the
    /// competition nor a status, so it only ever put a stale, unlabelled
    /// fixture in the user's calendar ahead of the live one. It is gone.
    ///
    /// Returns `nil` when the source could not be reached (so callers skip
    /// rather than wipe), and `[]` when it responded but has no upcoming
    /// games (so callers clear out stale events). Future fixtures only, and
    /// never a postponed or time-TBD one: a calendar entry is a promise about
    /// a time, so a game without a real kickoff stays off the calendar until
    /// it is rescheduled. It still shows on the app's Calendar tab.
    ///
    /// `hasSyncedEvents` says whether this entity's calendar already holds
    /// games. When it does, an empty `upcoming_fixtures` with a lone
    /// `next_fixture` means the page is half-written, not that the season came
    /// down to one match — collapsing to that single event wiped the other
    /// fourteen. Nothing synced yet (onboarding), and the single fixture is
    /// still better than an empty calendar.
    static func loadFixtures(teamId: String, hasSyncedEvents: Bool = false) async -> [GDFixture]? {
        // Keep a game that has already kicked off (within a ~3h grace covering
        // 90 mins + stoppage + extra time) so an in-progress match doesn't
        // vanish from the calendar the instant it starts. Older games fall off.
        let liveWindowStart = Date().addingTimeInterval(-3 * 60 * 60)

        do {
            guard let page = try await APIClient.shared.fetchTeamPage(teamId: teamId) else {
                return [] // responded, just no row
            }
            let upcoming = (page.cards.upcomingFixtures ?? []).compactMap { f -> GDFixture? in
                guard !f.isPostponed, !f.isTimeTBC,
                      let kickoff = parseISO(f.date), kickoff >= liveWindowStart
                else { return nil }
                return GDFixture(opponent: f.opponent, kickoffTime: kickoff, venue: f.venue,
                                 competition: calendarCompetition(leagueId: f.leagueId,
                                                                  label: f.importanceLabel))
            }
            if !upcoming.isEmpty { return upcoming }
            guard let next = page.cards.nextFixture,
                  let kickoff = parseISO(next.date), kickoff >= liveWindowStart
            else { return [] } // nothing upcoming at all: season over, clear it out
            // An empty upcoming list alongside a next fixture is a half-written
            // page, not a one-match season. Keep what she has.
            if hasSyncedEvents { return nil }
            return [GDFixture(opponent: next.opponent, kickoffTime: kickoff, venue: next.venue,
                              competition: calendarCompetition(leagueId: next.leagueId,
                                                               label: next.competition))]
        } catch {
            return nil // network/availability failure — caller leaves events alone
        }
    }

    /// The routine writes ISO 8601 with or without fractional seconds; a
    /// `.withInternetDateTime`-only parser silently dropped every fixture whose
    /// timestamp carried milliseconds. Same two-formatter dance as `InfoFixture`.
    private static func parseISO(_ raw: String) -> Date? {
        isoFractional.date(from: raw) ?? isoPlain.date(from: raw)
    }

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Lightweight fixture struct decoupled from API shapes. Callers
/// (e.g., the Settings toggle handler) build these from whatever
/// fixture source is currently available.
struct GDFixture {
    let opponent: String
    let kickoffTime: Date
    let venue: String?
    /// Competition and round, short form ("League Cup last 32"). Nil for a
    /// Premier League game, where every entry would carry it and none would
    /// need it. Empty and nil both mean "say nothing".
    var competition: String? = nil
}

/// The competition for a calendar title. The league id is the contract and
/// wins; the label is a fallback that only earns its place when it actually
/// names a competition we know — `importance_label` is routine prose
/// ("Survival fight at the Emirates", "Full time"), not a competition.
private func calendarCompetition(leagueId: Int?, label: String?) -> String? {
    if let leagueId, let competition = Competition(rawValue: leagueId) {
        return competition == .premierLeague ? nil : competition.name
    }
    guard let trimmed = calendarCompetition(label) else { return nil }
    return Competition.allCases.contains { $0.name == trimmed } ? trimmed : nil
}

/// Trim a competition label for a calendar title: no sponsor parenthetical, no
/// bare "Premier League" (every entry would carry it and none would need it).
private func calendarCompetition(_ raw: String?) -> String? {
    guard var label = raw?.trimmingCharacters(in: .whitespaces), !label.isEmpty else { return nil }
    if let paren = label.firstIndex(of: "(") {
        label = String(label[..<paren]).trimmingCharacters(in: .whitespaces)
    }
    label = label.trimmingCharacters(in: CharacterSet(charactersIn: ","))
    if label.isEmpty || label == "Premier League" || label == "Fixture" { return nil }
    return label
}
