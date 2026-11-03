import UIKit
import UserNotifications
import FBSDKCoreKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Meta SDK first, before anything else Facebook-related (app events +
        // SKAdNetwork; no Login). Auto-logging handles `fb_mobile_activate_app`
        // itself on applicationDidBecomeActive — never also call
        // AppEvents.shared.activateApp(), that double-logs. IOS_GOTCHAS §18.
        Attribution.sdkLaunched = ApplicationDelegate.shared.application(
            application, didFinishLaunchingWithOptions: launchOptions
        )
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        #if DEBUG
        Attribution.selfCheck()
        assert(MatchdaySection.selfCheck(), "Matchday opens on the wrong section")
        assert(NamedPlayer.selfCheck(), "Who's who matches the wrong players")
        assert(SharedAnalytics.pushKind("live-goal-123") == "goal" && SharedAnalytics.pushKind("myturn-prep-arsenal-9") == "prep"
               && SharedAnalytics.pushKind("matchday-arsenal-9") == "matchday" && SharedAnalytics.pushKind("fixture:9") == "fixture"
               && SharedAnalytics.pushKind(UUID().uuidString) == "article" && SharedAnalytics.pushKind(nil) == "none",
               "push_opened kinds drifted")
        assert(ImmersiveCard.matchdayLabel(result: "Newcastle 1-3 Everton", teamId: "newcastle") == "After Everton:"
               && ImmersiveCard.matchdayLabel(result: "Everton 3-1 Newcastle (AET)", teamId: "newcastle") == "After Everton:"
               && ImmersiveCard.matchdayLabel(result: "Man United 2-0 Spurs", teamId: "man_utd") == "After Spurs:"
               && ImmersiveCard.matchdayLabel(result: "Arsenal 1-1 Fleetwood Town (Arsenal won 4-3 on penalties)", teamId: "arsenal") == "After Fleetwood Town:"
               && ImmersiveCard.matchdayLabel(result: nil, teamId: "arsenal") == "After the game:",
               "result card label names the wrong side")
        assert(["SUSP": "Suspended", "INT": "Interrupted", "ABD": "Abandoned", "PST": "Postponed", "LIVE": "In play", "P": "Penalties"]
                .allSatisfy { LiveMatchSnapshot(fixtureId: 0, homeTeamId: "", awayTeamId: "", homeName: nil, awayName: nil, homeGoals: 0,
                                                awayGoals: 0, status: $0.key, elapsed: nil, clockStart: nil, groupLabel: nil).statusLabel == $0.value }
               && LiveMatchSnapshot.pausedLabels == ["Suspended", "Interrupted"],
               "Live Activity status words drifted from wcStatusLabel")
        assert(TeamPageFormDots.results("wWDL-") == ["W", "W", "D", "L"], "form dots reorder or keep junk")
        let injuries = [TeamInjury(name: "B. Saka", reason: "Hamstring"), TeamInjury(name: "Gabriel Jesus", reason: "Knee"),
                        TeamInjury(name: "J. Timber", reason: "Ankle"), TeamInjury(name: "Jurriën Timber", reason: "Ankle")]
        assert(TeamInjury.reason(for: "Bukayo Saka", in: injuries) == "Hamstring"
               && TeamInjury.reason(for: "G. Jesus", in: injuries) == "Knee"
               && TeamInjury.reason(for: "Declan Rice", in: injuries) == nil
               && TeamInjury.reason(for: "Jurrien Timber", in: injuries) == nil,   // two rows: not sure which
               "Out tag matches the wrong man")
        func last(_ us: Int, _ them: Int, _ state: TeamPostMatchCard.TeamPostMatchState) -> LastMatchCard {
            LastMatchCard(fixtureId: 1, kickoff: "2026-10-28T19:45:00Z", finishedAt: "2026-10-28T22:00:00Z", competition: nil,
                          opponent: "Chelsea", venue: "home", teamScore: us, oppScore: them, state: state, verdict: "",
                          talkingPoint: "", goals: [], numbers: [], expiresAt: "2026-11-04T22:00:00Z")
        }
        let shootout = RecentResult(date: "2026-10-28T19:45:00+00:00", opponent: "Chelsea", venue: "home",
                                    teamScore: 1, oppScore: 1, result: "L", penTeam: 5, penOpp: 6)
        assert(last(1, 2, .loss).afterLine(recent: []) == "After Chelsea: lost 2-1"
               && last(1, 1, .draw).afterLine(recent: []) == "After Chelsea: drew 1-1"
               && last(1, 1, .loss).afterLine(recent: [shootout]) == "After Chelsea: lost 6-5 on pens"
               && last(1, 1, .win).afterLine(recent: []) == "After Chelsea: won on pens",
               "club page's After line misreads the result")
        assert(MyTurnModule.selfCheck(), "My Turn opens on the wrong module or loses a retired one")
        assert(QuizView.selfCheck(), "Quiz shows the wrong packs before More packs")
        assert(LiveClubPack.clubSelfCheck(), "the club pack misreads form or a shootout")
        assert(LiveSquadPack.injurySelfCheck(), "an injured man got a line that sends her looking for him")
        assert(LingoCalendar.selfCheck(), "the transfer window is open on the wrong days")
        let named = QuizPack(id: "t", label: "t", questions: [MyTurnQuestion(
            id: "q", difficulty: 1, question: "[His name] asks", options: ["[her name]", "[Her name's] call"], answer: 0,
            explanation: "the kind of chances that get [his name] off the sofa", use: "[His name's] one to watch")])
            .personalised(AppState.shared.personalise).questions[0]
        assert(!([named.question, named.explanation, named.use ?? ""] + named.options).contains(where: hasNamePlaceholder)
               && hasNamePlaceholder("get [his name] off") && hasNamePlaceholder("[Her name's] call") && hasNamePlaceholder("hi {name}")
               && !hasNamePlaceholder("Arsenal [4-3 pens] his name"),
               "a quiz line keeps [his name] for her to read")
        Task { @MainActor in
            let ordered = await LatestOnlyQueue.selfCheck()
            assert(ordered, "push registrations can overtake each other; the server may keep the older follow set")
            print("✅ LatestOnlyQueue self-check passed")
        }
        #endif

        UNUserNotificationCenter.current().delegate = self

        // V2.0: image cache for AsyncImage. The CountrySelectionView (48
        // flags) and Meet team/manager views (player + manager headshots)
        // all hit api-sports.io CDN — without a shared cache each appearance
        // triggers a fresh network fetch, thrashing on scroll. 20 MB memory
        // + 100 MB disk covers all crests/flags/headshots with room to spare
        // (each PNG is ~5-50 KB).
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "image_cache"
        )

        // Global rose cursor tint on all text fields and text views
        let roseTint = UIColor(red: 232/255, green: 57/255, blue: 125/255, alpha: 1)
        UITextField.appearance().tintColor = roseTint
        UITextView.appearance().tintColor = roseTint

        // TEST A: temporarily disabled — UIScrollView.appearance() applies to
        // every scroll view in the app, including the one UITextField uses
        // internally to scroll long text. That's why typing a long word turned
        // the input field's background dark mauve.
        // Deep mauve overscroll background (prevents white flash on rubber-band)
        // UIScrollView.appearance().backgroundColor = UIColor(red: 45/255, green: 27/255, blue: 46/255, alpha: 1)

        // Verify custom fonts are registered correctly
        #if DEBUG
        for family in UIFont.familyNames.sorted() where family.contains("Jakarta") || family.contains("League") {
            print("Font family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
        #endif

        // Ask iOS for the APNs token on EVERY launch while authorized, as Apple
        // advises: the token can change (restore, new device) and this is the
        // only way the app hears about it. Delivery goes through
        // handleTokenRegistration, whose token + scope guard keeps an unchanged
        // token from re-POSTing, and which also retries a POST that failed.
        Task { @MainActor in
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if status == .authorized || status == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        // Observe Live Activity tokens (push-to-start + per-activity update
        // tokens) so the backend can start/update live match activities on
        // the Lock Screen + Dynamic Island. Idempotent. Not before onboarding:
        // the push-to-start token would register with nothing followed (and
        // recreate a server row right after Delete My Data).
        // OnboardingFlow.completeOnboarding starts it for a new install.
        if AppState.shared.hasCompletedOnboarding {
            LiveActivityManager.shared.start()
        }

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Real iOS devices emit a 32-byte (64 hex char) APNs token. iOS 17+
        // simulators can emit a longer "extended" format (80 bytes / 160 hex
        // chars) intended for simulator-only push testing. Backend validators
        // — both the `register-dev-device` Edge Function regex and the
        // `valid_apns_token` DB CHECK constraint — reject anything that isn't
        // exactly 64 hex chars. Truncating here keeps sim flow valid for
        // local smoke tests; on a real device the prefix is a no-op since
        // the raw string is already 64 chars.
        let raw = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let token = String(raw.prefix(64))
        NotificationService.shared.handleTokenRegistration(token)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("⚠️ APNs registration failed: \(error)")
        #endif
    }

    // Facebook `fb<app-id>://` callbacks (deferred app links / ad attribution).
    // The SwiftUI scene has no other URL consumer, so forwarding here is enough.
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        ApplicationDelegate.shared.application(app, open: url, options: options)
    }

    // Notification tapped
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let contentId = userInfo["content_id"] as? String
        let teamId = userInfo["team_id"] as? String
        AppState.shared.pushTapTick += 1
        Analytics.shared.log(.pushOpened, ["kind": SharedAnalytics.pushKind(contentId), "club": teamId ?? ""])
        routeFeedContext(teamId: teamId,
                         everyoneTalking: userInfo["everyone_talking"] as? Bool == true)
        // Matchday follows the switcher, which routeFeedContext has just moved
        // to the push's club, so a pre-game or full-time push about either
        // club opens Matchday on that club. One about a club she no longer
        // follows lands on the feed.
        let forMatchdayClub = teamId == nil || teamId == AppState.shared.contextTeam?.rawValue
        // The pre-game push opens Matchday › Before, the full-time push
        // (`live-ft-<fixture>`, match-watcher) opens Matchday › After.
        if let contentId, contentId.hasPrefix("myturn-prep"), forMatchdayClub {
            AppState.shared.pendingOpenPrep = true
        } else if let contentId, contentId.hasPrefix("live-ft-"), forMatchdayClub {
            AppState.shared.pendingOpenAfter = true
        } else if let contentId, let uuid = UUID(uuidString: contentId) {
            AppState.shared.deepLinkContentId = uuid
        } else {
            // Live (kickoff, goal, HT, FT), matchday and fixture pushes carry
            // no article. They used to do nothing, so the app opened on
            // whatever feed was last showing — often Football.
            AppState.shared.pendingOpenFeed = true
        }
        completionHandler()
    }


    /// Which feed a tapped push opens on. A push about one of her clubs
    /// always lands on that club: until 2026-10-26 no push carried a team, a
    /// club article flagged everyone_talking moved her to Football, and
    /// Football then stuck — every later push opened there too. Only a push
    /// with no club of hers behind it may open Football.
    private func routeFeedContext(teamId: String?, everyoneTalking: Bool) {
        let state = AppState.shared
        if let teamId, let team = Team(rawValue: teamId), state.selectedTeams.contains(team) {
            state.activeContext = .team(team)
        } else if let teamId, let country = Country(rawValue: teamId),
                  CountryFollowing.isEnabled, state.selectedCountries.contains(country) {
            state.activeContext = .country(country)
        } else if everyoneTalking {
            state.activeContext = .everyoneTalking
        } else if state.activeContext == .everyoneTalking, let team = state.selectedTeams.first {
            // An older backend sends no team_id. A club push must still not
            // leave her on Football.
            state.activeContext = .team(team)
        }
    }

    // Notification received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
