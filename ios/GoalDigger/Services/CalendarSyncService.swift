import EventKit
import Foundation

/// One-way sync of his team's fixtures into the user's iOS calendar.
///
/// All events live in a dedicated "GoalDigger - <team>" calendar so the user
/// can hide or delete them in one move. Swapping team in Settings removes the
/// old calendar and creates a new one. Toggling off removes all GoalDigger
/// calendars.
@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()
    private let store = EKEventStore()

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

    /// Sync the given fixtures into a calendar named "GoalDigger - <team>".
    /// Wipes prior events in that calendar, then inserts the new set. Also
    /// removes any other "GoalDigger - <other team>" calendars so a team
    /// change leaves no orphan events behind.
    func sync(teamShortName: String, fixtures: [GDFixture]) async throws {
        try removeOtherGoalDiggerCalendars(keeping: teamShortName)

        let title = "GoalDigger - \(teamShortName)"
        let calendar = try findOrCreateCalendar(title: title)

        // Wipe existing future events
        let now = Date()
        let oneYearOut = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: oneYearOut, calendars: [calendar])
        for event in store.events(matching: predicate) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }
        try store.commit()

        // Insert fresh fixtures
        for fixture in fixtures {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            // Encode home/away into the title rather than event.location.
            // `fixture.venue` upstream is just the literal "home" / "away"
            // enum from team-page-generator (no stadium name available), so
            // putting it in Calendar's Location field would surface
            // "home" / "away" as the event location — confusing in iOS
            // Calendar where Location is typically an address. Title-suffix
            // approach keeps the signal without misusing the field.
            let venueSuffix: String = {
                guard let v = fixture.venue?.lowercased() else { return "" }
                if v == "home" { return " (Home)" }
                if v == "away" { return " (Away)" }
                return ""
            }()
            event.title = "\(teamShortName) vs \(fixture.opponent)\(venueSuffix)"
            event.startDate = fixture.kickoffTime
            event.endDate = fixture.kickoffTime.addingTimeInterval(2 * 60 * 60)
            event.notes = "Match day. Open GoalDigger for prep."
            try? store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    /// Remove every "GoalDigger - *" calendar from the store.
    func removeAllGoalDiggerCalendars() throws {
        for c in store.calendars(for: .event) where c.title.hasPrefix("GoalDigger - ") {
            try store.removeCalendar(c, commit: false)
        }
        try store.commit()
    }

    private func removeOtherGoalDiggerCalendars(keeping teamShortName: String) throws {
        let keepTitle = "GoalDigger - \(teamShortName)"
        for c in store.calendars(for: .event)
            where c.title.hasPrefix("GoalDigger - ") && c.title != keepTitle {
            try store.removeCalendar(c, commit: false)
        }
        try store.commit()
    }

    private func findOrCreateCalendar(title: String) throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == title }) {
            return existing
        }
        guard let source = store.defaultCalendarForNewEvents?.source else {
            throw SyncError.noWritableSource
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = title
        cal.source = source
        try store.saveCalendar(cal, commit: true)
        return cal
    }
}

/// Lightweight fixture struct decoupled from API shapes. Callers
/// (e.g., the Settings toggle handler) build these from whatever
/// fixture source is currently available.
struct GDFixture {
    let opponent: String
    let kickoffTime: Date
    let venue: String?
}
