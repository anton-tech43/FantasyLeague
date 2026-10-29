import Foundation
import UIKit

/// The usage events we log to our own table (docs/TRACKING_PLAN.md).
/// rawValues must equal the `allowed` array in `log_events` (migration 142);
/// `scripts/verify-tracking-plan.sh` fails when they drift.
enum AnalyticsEvent: String, CaseIterable {
    case appOpened = "app_opened"
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingCompleted = "onboarding_completed"
    case pushOpened = "push_opened"
    case tabViewed = "tab_viewed"
    case settingsOpened = "settings_opened"
    case feedCardOpened = "feed_card_opened"
    case lineShared = "line_shared"
    case lineSaved = "line_saved"
    case myTurnModuleSwitched = "my_turn_module_switched"
    case pregameOpened = "pregame_opened"
    case matchdayAfterOpened = "matchday_after_opened"
    case pregameCardCompleted = "pregame_card_completed"
    case practiceCompleted = "practice_completed"
    case overheardRoundFinished = "overheard_round_finished"
    case hypeShown = "hype_shown"
    case followChanged = "follow_changed"
    case tierChanged = "tier_changed"
    case notificationPermissionChanged = "notification_permission_changed"
    case notificationsBanner = "notifications_banner"
    case settingsRowOpened = "settings_row_opened"
    case dataDeleted = "data_deleted"
}

/// First-party usage events: queued on the phone, sent in batches through
/// `log_events`, never one request per event. Nothing here carries her name,
/// his name, free text or the push token (the RPC refuses any prop value that
/// is not a short scalar).
@MainActor
final class Analytics {
    static let shared = Analytics()

    private let defaults = UserDefaults.standard
    private let queueKey = "analyticsQueue"
    private let idKey = "analyticsInstallId"
    private let sinceKey = "analyticsInstallSince"
    private let flushAt = 30
    /// Under the RPC's 8 KB cap with room for the wrapper.
    private let maxBatchBytes = 7_000
    private var queue: [[String: Any]]
    private var flushing = false

    private(set) var installId: UUID
    private var installedAt: Date

    private init() {
        if let s = defaults.string(forKey: idKey), let id = UUID(uuidString: s) {
            installId = id
        } else {
            installId = UUID()
            defaults.set(installId.uuidString, forKey: idKey)
        }
        installedAt = defaults.object(forKey: sinceKey) as? Date ?? Date()
        defaults.set(installedAt, forKey: sinceKey)
        queue = (defaults.data(forKey: queueKey))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
    }

    /// Log one event. `props` values must be String, Int, Double or Bool.
    func log(_ event: AnalyticsEvent, _ props: [String: Any] = [:]) {
        let state = AppState.shared
        var all: [String: Any] = [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            // "development" from Xcode builds; every view keeps production only.
            "env": APIClient.apnsEnvironment,
            "tier": state.selectedTier,
            "relationship": state.relationshipType.rawValue,
            "days_since_install": Calendar.current.dateComponents([.day], from: installedAt, to: Date()).day ?? 0,
        ]
        if let club = state.selectedTeam?.rawValue { all["club"] = club }
        // ponytail: next_fixture_in_hours (TRACKING_PLAN common props) is left
        // out; the pre-game events carry fixture_id, which the SQL joins to
        // kickoff. Add it here if a query ever needs it on every event.
        all.merge(props) { _, new in new }
        queue.append([
            "name": event.rawValue,
            "at": ISO8601DateFormatter().string(from: Date()),
            "props": all,
        ])
        save()
        if queue.count >= flushAt { flush() }
    }

    /// Send what is queued. Called at every 30 events and when the app goes
    /// to the background.
    func flush() {
        guard !flushing, !queue.isEmpty, APIClient.shared.isConfigured else { return }
        dropStale()
        flushing = true
        Task {
            defer { flushing = false }
            while let (count, data) = nextBatch() {
                do {
                    try await APIClient.shared.logEvents(installId: installId, events: data)
                    queue.removeFirst(count)
                } catch APIError.httpError(let code) where (400..<500).contains(code) {
                    // Refused (an event name this server does not know yet,
                    // say): resending would be refused forever, so drop it.
                    queue.removeFirst(count)
                } catch {
                    break // offline or server down: keep the queue for next time
                }
                save()
            }
        }
    }

    /// Delete My Data: the exit is sent first (the server deletes every event
    /// for this install and keeps the exit without an id), then a new install
    /// id so nothing after links back.
    func forgetInstall(_ exitProps: [String: Any]) async {
        log(.dataDeleted, exitProps)
        while let (count, data) = nextBatch() {
            guard (try? await APIClient.shared.logEvents(installId: installId, events: data)) != nil else { break }
            queue.removeFirst(count)
        }
        queue = []
        save()
        installId = UUID()
        installedAt = Date()
        defaults.set(installId.uuidString, forKey: idKey)
        defaults.set(installedAt, forKey: sinceKey)
    }

    /// The oldest events that fit in one request, up to the RPC's 50.
    private func nextBatch() -> (Int, Data)? {
        guard !queue.isEmpty else { return nil }
        var n = min(50, queue.count)
        while n > 0 {
            if let data = try? JSONSerialization.data(withJSONObject: Array(queue.prefix(n))),
               data.count <= maxBatchBytes {
                return (n, data)
            }
            n -= 1
        }
        queue.removeFirst() // one event over the cap can never be sent
        return nextBatch()
    }

    /// The server clamps anything older than 8 days; past 7 offline it is dropped here.
    private func dropStale() {
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        let f = ISO8601DateFormatter()
        queue.removeAll { ($0["at"] as? String).flatMap(f.date(from:)).map { $0 < cutoff } ?? true }
    }

    private func save() {
        defaults.set(try? JSONSerialization.data(withJSONObject: queue), forKey: queueKey)
    }
}
