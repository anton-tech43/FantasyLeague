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
    func resync(team: Team?, country: Country?) async throws {
        // Fresh view of the store: this long-lived EKEventStore otherwise holds
        // a stale snapshot after the user edits/deletes calendars outside the
        // app (the old "added once, deleted, won't re-add" bug).
        store.reset()

        let followed: [(shortName: String, teamId: String)] = [
            country.map { (shortName: $0.shortName, teamId: $0.rawValue) },
            team.map { (shortName: $0.shortName, teamId: $0.rawValue) },
        ].compactMap { $0 }
        let followedTitles = Set(followed.map { calendarTitle($0.shortName) })

        // 1. Remove calendars for entities the user no longer follows (e.g. an
        //    old club after a team switch). Derived purely from app state, so
        //    it's safe regardless of network.
        for c in store.calendars(for: .event)
        where c.title.hasPrefix(titlePrefix) && !followedTitles.contains(c.title) {
            try? store.removeCalendar(c, commit: false)
        }
        try store.commit()

        // 2. Refresh each followed entity from authoritative fixtures.
        for entity in followed {
            guard let fixtures = await Self.loadFixtures(teamId: entity.teamId) else {
                continue // fetch failed — leave existing events intact this round
            }
            try writeCalendar(shortName: entity.shortName, fixtures: fixtures)
        }
    }

    /// Launch / foreground hook: best-effort, non-prompting, throttled. No-op
    /// unless the user enabled sync AND already granted full calendar access
    /// (we never trigger the permission prompt from a background-resume path).
    func autoResync(team: Team?, country: Country?, enabled: Bool) async {
        guard enabled else { return }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        if let last = lastAutoResyncAt, Date().timeIntervalSince(last) < 30 * 60 { return }
        lastAutoResyncAt = Date() // set before awaiting so a rapid re-entry no-ops
        try? await resync(team: team, country: country)
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

        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        let end = cal.date(byAdding: .year, value: 1, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        for event in store.events(matching: predicate) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }
        try store.commit()

        for fixture in fixtures {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            // Encode home/away into the title rather than event.location:
            // `fixture.venue` is just the literal "home"/"away" enum (no stadium
            // name), so the Location field would surface "home"/"away" as the
            // event location, which is confusing in iOS Calendar.
            event.title = "\(shortName) vs \(fixture.opponent)\(venueSuffix(fixture.venue))"
            event.startDate = fixture.kickoffTime
            event.endDate = fixture.kickoffTime.addingTimeInterval(2 * 60 * 60)
            event.notes = "Match day. Open GoalDigger for prep."
            // Propagate save failures (a silent failure here is exactly the
            // "it doesn't add" symptom).
            try store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
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

    /// Authoritative upcoming fixtures for one entity (club or country).
    /// Returns `nil` when NEITHER source could be reached (so callers skip
    /// rather than wipe), and `[]` when a source responded but has no upcoming
    /// games (so callers clear out stale events). Future fixtures only.
    static func loadFixtures(teamId: String) async -> [GDFixture]? {
        let now = Date()
        var reachedASource = false

        // 1. Season state (richer — up to ~10 fixtures).
        do {
            if let state = try await APIClient.shared.fetchTeamSeasonState(teamId: teamId) {
                reachedASource = true
                let fx = state.fixturesForSync
                    .filter { $0.kickoffTime >= now }
                    .map { GDFixture(opponent: $0.opponent, kickoffTime: $0.kickoffTime, venue: $0.venue) }
                if !fx.isEmpty { return fx }
            } else {
                reachedASource = true // responded, just no row
            }
        } catch {
            // network/availability failure — fall through to the page source
        }

        // 2. Team page fallback (full upcoming list, else the singular next).
        do {
            if let page = try await APIClient.shared.fetchTeamPage(teamId: teamId) {
                reachedASource = true
                let upcoming = (page.cards.upcomingFixtures ?? []).compactMap { f -> GDFixture? in
                    guard let kickoff = isoFormatter.date(from: f.date), kickoff >= now else { return nil }
                    return GDFixture(opponent: f.opponent, kickoffTime: kickoff, venue: f.venue)
                }
                if !upcoming.isEmpty { return upcoming }
                if let next = page.cards.nextFixture,
                   let kickoff = isoFormatter.date(from: next.date), kickoff >= now {
                    return [GDFixture(opponent: next.opponent, kickoffTime: kickoff, venue: next.venue)]
                }
            } else {
                reachedASource = true
            }
        } catch {
            // network/availability failure
        }

        return reachedASource ? [] : nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
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
}
