import Foundation
import StoreKit
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
    /// Written by the server (`delete_app_events`, migration 148), never by
    /// `log()`; still in the RPC's allow-list for older builds.
    case dataDeleted = "data_deleted"
    /// Logged by the Notification Service Extension, never by the app.
    case pushDelivered = "push_delivered"
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
    private var flushTask: Task<Void, Never>?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    /// "appstore", "testflight" or "debug" (migration 149). Per launch, never
    /// stored: a TestFlight install updated from the App Store keeps its
    /// UserDefaults but is no longer a TestFlight build.
    private var channel: String?

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
        SharedAnalytics.defaults?.set(installId.uuidString, forKey: SharedAnalytics.installIdKey)
        Task { _ = await resolveChannel() }
    }

    /// AppTransaction rather than the receipt URL: `appStoreReceiptURL` is
    /// deprecated from iOS 18 and the receipt file need not exist. Read-only:
    /// this never touches a purchase or an entitlement. TestFlight is the
    /// sandbox environment; Xcode builds never ask.
    private func resolveChannel() async -> String {
        #if DEBUG
        return "debug"
        #else
        if let channel { return channel }
        guard let env = (try? await AppTransaction.shared)?.unsafePayloadValue.environment else { return "unknown" }
        let resolved = env == .production ? "appstore" : env == .sandbox ? "testflight" : "debug"
        channel = resolved
        return resolved
        #endif
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
        // Also stamped at send time (nextBatch), for events logged before
        // AppTransaction answered; here so the extension's copy carries it.
        if let channel { all["channel"] = channel }
        // The extension logs deliveries while the app is closed; it splits
        // them by these. days_since_install would be stale there, so it stays.
        SharedAnalytics.defaults?.set(all.filter { $0.key != "days_since_install" },
                                      forKey: SharedAnalytics.commonPropsKey)
        // ponytail: next_fixture_in_hours (TRACKING_PLAN common props) is left
        // out; the pre-game events carry fixture_id, which the SQL joins to
        // kickoff. Add it here if a query ever needs it on every event.
        all.merge(props) { _, new in new }
        if event == .pregameCardCompleted, props["phase"] as? String == "before" {
            Attribution.logActivatedOnce()
        }
        queue.append([
            "name": event.rawValue,
            "at": ISO8601DateFormatter().string(from: Date()),
            "props": all,
        ])
        save()
        if queue.count >= flushAt { flush() }
    }

    /// Send what is queued. Called at every 30 events and when the app leaves
    /// the foreground. Returns the send in flight, so a caller can wait for it.
    @discardableResult
    func flush() -> Task<Void, Never>? {
        if let flushTask { return flushTask }
        guard !queue.isEmpty, APIClient.shared.isConfigured else { return nil }
        dropStale()
        let task = Task {
            let channel = await resolveChannel()
            while let (count, data) = nextBatch(channel: channel) {
                do {
                    try await APIClient.shared.logEvents(installId: installId, events: data)
                    queue.removeFirst(min(count, queue.count))
                } catch APIError.httpError(let code) where (400..<500).contains(code) {
                    // Refused (an event name this server does not know yet,
                    // say): resending would be refused forever, so drop it.
                    queue.removeFirst(min(count, queue.count))
                } catch {
                    break // offline or server down: keep the queue for next time
                }
                save()
            }
            flushTask = nil
        }
        flushTask = task
        return task
    }

    /// The app is going to the background. The queue is already on disk
    /// (save() runs on every log; written again here so nothing rests on
    /// that), and iOS is asked for time so the request completes before the
    /// app is suspended. Onboarding drop-offs were the events this lost.
    func flushBeforeSuspend() {
        save()
        guard backgroundTask == .invalid, let task = flush() else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "analytics-flush") {
            // Out of time: what is unsent stays queued for the next launch.
            MainActor.assumeIsolated { Analytics.shared.endBackgroundTask() }
        }
        Task {
            await task.value
            endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    /// Delete My Data. The server deletes every event for this install and
    /// keeps one anonymous line, the days since install (migration 148). Only
    /// after it said yes does the install id change, so a failed delete throws
    /// and can be retried against the same id; until now a failure rotated
    /// the id anyway and left her rows unreachable.
    ///
    /// Purchases are not ours to forget, and not ours to lose: they are
    /// restored from her Apple ID through StoreKit, never from this install
    /// id. Nothing here touches StoreKit or an entitlement, and no
    /// purchase-related key belongs in what is cleared below.
    func forgetInstall() async throws {
        // A batch in flight would land after the delete under the old id.
        await flushTask?.value
        if APIClient.shared.isConfigured {
            let days = Calendar.current.dateComponents([.day], from: installedAt, to: Date()).day ?? 0
            try await APIClient.shared.deleteAppEvents(installId: installId, daysSinceInstall: days,
                                                       channel: await resolveChannel())
        }
        // Unsent events are hers too; the extension's copy of her club, tier
        // and relationship goes with them.
        queue = []
        defaults.removeObject(forKey: queueKey)
        SharedAnalytics.defaults?.removeObject(forKey: SharedAnalytics.commonPropsKey)
        installId = UUID()
        installedAt = Date()
        defaults.set(installId.uuidString, forKey: idKey)
        defaults.set(installedAt, forKey: sinceKey)
        SharedAnalytics.defaults?.set(installId.uuidString, forKey: SharedAnalytics.installIdKey)
    }

    /// The oldest events that fit in one request, up to the RPC's 50, each
    /// stamped with the build's channel if it was logged before it was known.
    private func nextBatch(channel: String) -> (Int, Data)? {
        guard !queue.isEmpty else { return nil }
        let stamped = queue.prefix(50).map { event -> [String: Any] in
            var event = event
            var props = event["props"] as? [String: Any] ?? [:]
            if props["channel"] == nil { props["channel"] = channel }
            event["props"] = props
            return event
        }
        var n = stamped.count
        while n > 0 {
            if let data = try? JSONSerialization.data(withJSONObject: Array(stamped.prefix(n))),
               data.count <= maxBatchBytes {
                return (n, data)
            }
            n -= 1
        }
        queue.removeFirst() // one event over the cap can never be sent
        return nextBatch(channel: channel)
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
