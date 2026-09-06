import Foundation
import ActivityKit

/// Owns the Live Activity lifecycle for live matches of the followed teams:
/// WC countries and, since Sept 2026, PL clubs (clubs show a short name and no
/// flag; the widget can't load crests).
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
    /// carries ALL followed countries and clubs, so it triggers for whichever
    /// plays. Empty arrays are fine — the backend broadcasts WC knockout Live
    /// Activities to every registered token, so every device registers even
    /// with nothing followed. Safe to call repeatedly — backend upserts on the
    /// token.
    func registerPushToStartIfPossible() async {
        guard let token = UserDefaults.standard.string(forKey: Self.ptsTokenKey) else { return }
        try? await APIClient.shared.registerLiveActivityToken(
            token, kind: "push_to_start", fixtureId: nil,
            countryIds: Self.followedCountryIds, teamIds: Self.followedTeamIds)
    }

    private static var followedCountryIds: [String] { AppState.shared.selectedCountries.map(\.rawValue) }
    private static var followedTeamIds: [String] { AppState.shared.selectedTeams.map(\.rawValue) }

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
                    countryIds: Self.followedCountryIds, teamIds: Self.followedTeamIds)
            }
        }
    }

    // MARK: Foreground-start fallback

    /// On foreground: re-assert the push-to-start registration, and if a
    /// followed team has a live match with no running activity, start one
    /// locally (which vends its update token to the backend).
    func syncForegroundActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { await registerPushToStartIfPossible() }
        let followedIds = Self.followedCountryIds + Self.followedTeamIds
        Task {
            // Check each followed team — any could be live (e.g. his Arsenal
            // and her Sweden). startOrUpdate is keyed by fixtureId so two live
            // matches each get their own activity. live-match-current matches
            // on home/away id, so a club slug works the same as a country slug.
            for entityId in followedIds {
                guard let snap = try? await APIClient.shared.fetchCurrentLiveMatch(countryId: entityId),
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

        guard let home = Self.side(snap.homeTeamId),
              let away = Self.side(snap.awayTeamId) else { return }

        let attributes = MatchActivityAttributes(
            fixtureId: snap.fixtureId,
            homeName: home.name,
            awayName: away.name,
            homeFlag: home.flag,
            awayFlag: away.flag,
            groupLabel: snap.groupLabel)

        // pushType: .token so iOS vends an update token → observeToken registers
        // it → the backend takes over live updates through to full-time.
        _ = try? Activity.request(attributes: attributes, content: content, pushType: .token)
    }

    /// Display side for a country or club slug. Mirrors the backend's liveMeta:
    /// countries carry an emoji flag, clubs an empty one (the widget hides it).
    private static func side(_ id: String) -> (name: String, flag: String)? {
        if let c = Country(rawValue: id) { return (c.shortName, c.flagEmoji) }
        if let t = Team(rawValue: id) { return (t.shortName, "") }
        return nil
    }
}

private extension Data {
    var gdHexString: String { map { String(format: "%02x", $0) }.joined() }
}
