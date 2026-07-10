import Foundation
import ActivityKit

/// Owns the Live Activity lifecycle for live WC matches.
///
/// Two token flows feed the backend so it can drive the activity remotely:
///   - push-to-start token (per install, iOS 17.2+): lets the backend START
///     the activity at kickoff without the app open.
///   - per-activity update token (each running activity): lets the backend
///     UPDATE/END that specific activity.
/// A foreground-start fallback covers the rare case where push-to-start hasn't
/// fired (older OS, or the install hasn't vended/registered its token yet).
///
/// Deployment target is 17.0, so all ActivityKit APIs are available; only
/// push-to-start needs the 17.2 guard.
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var started = false
    private static let ptsTokenKey = "liveActivityPushToStartToken"

    /// Begin observing tokens. Idempotent; call once at launch.
    func start() {
        guard !started else { return }
        started = true
        observeUpdateTokens()
        if #available(iOS 17.2, *) { observePushToStartToken() }
    }

    // MARK: Push-to-start (iOS 17.2+)

    @available(iOS 17.2, *)
    private func observePushToStartToken() {
        Task {
            for await tokenData in Activity<MatchActivityAttributes>.pushToStartTokenUpdates {
                UserDefaults.standard.set(tokenData.gdHexString, forKey: Self.ptsTokenKey)
                await registerPushToStartIfPossible()
            }
        }
    }

    /// Re-assert the push-to-start registration. V2.2: the single PTS token
    /// carries ALL followed countries, so it triggers for whichever plays.
    /// An empty countryIds array is fine — the backend broadcasts knockout
    /// Live Activities to every registered token, so every device registers
    /// even with no followed country. Safe to call repeatedly — backend
    /// upserts on the token.
    func registerPushToStartIfPossible() async {
        guard let token = UserDefaults.standard.string(forKey: Self.ptsTokenKey) else { return }
        let countryIds = AppState.shared.selectedCountries.map(\.rawValue)
        try? await APIClient.shared.registerLiveActivityToken(
            token, kind: "push_to_start", fixtureId: nil, countryIds: countryIds)
    }

    // MARK: Per-activity update tokens

    private func observeUpdateTokens() {
        Task {
            for await activity in Activity<MatchActivityAttributes>.activityUpdates {
                observeToken(of: activity)
            }
        }
    }

    private func observeToken(of activity: Activity<MatchActivityAttributes>) {
        Task {
            for await tokenData in activity.pushTokenUpdates {
                try? await APIClient.shared.registerLiveActivityToken(
                    tokenData.gdHexString, kind: "update",
                    fixtureId: activity.attributes.fixtureId,
                    countryIds: AppState.shared.selectedCountries.map(\.rawValue))
            }
        }
    }

    // MARK: Foreground-start fallback

    /// On foreground: re-assert the push-to-start registration, and if the
    /// followed country has a live match with no running activity, start one
    /// locally (which vends its update token to the backend).
    func syncForegroundActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { await registerPushToStartIfPossible() }
        let countryIds = AppState.shared.selectedCountries.map(\.rawValue)
        Task {
            // Check each followed country — either could be live (e.g. his
            // Norway and her Sweden). startOrUpdate is keyed by fixtureId so
            // two live matches each get their own activity.
            for countryId in countryIds {
                guard let snap = try? await APIClient.shared.fetchCurrentLiveMatch(countryId: countryId),
                      snap.isLive else { continue }
                startOrUpdate(from: snap)
            }
            // Tournament-wide: whichever World Championship match is live
            // right now, for every user. If it's also a followed country's
            // match, the fixtureId key in startOrUpdate dedupes it into an
            // update rather than a second activity.
            if let snap = try? await APIClient.shared.fetchCurrentLiveMatch(
                   countryId: FeedContext.worldChampionshipEntityId),
               snap.isLive {
                startOrUpdate(from: snap)
            }
        }
    }

    private func startOrUpdate(from snap: LiveMatchSnapshot) {
        let content = ActivityContent(state: snap.contentState, staleDate: nil)

        if let existing = Activity<MatchActivityAttributes>.activities
            .first(where: { $0.attributes.fixtureId == snap.fixtureId }) {
            Task { await existing.update(content) }
            return
        }

        guard let home = Country(rawValue: snap.homeTeamId),
              let away = Country(rawValue: snap.awayTeamId) else { return }

        let attributes = MatchActivityAttributes(
            fixtureId: snap.fixtureId,
            homeName: home.shortName,
            awayName: away.shortName,
            homeFlag: home.flagEmoji,
            awayFlag: away.flagEmoji,
            groupLabel: snap.groupLabel)

        // pushType: .token so iOS vends an update token → observeToken registers
        // it → the backend takes over live updates through to full-time.
        _ = try? Activity.request(attributes: attributes, content: content, pushType: .token)
    }
}

private extension Data {
    var gdHexString: String { map { String(format: "%02x", $0) }.joined() }
}
