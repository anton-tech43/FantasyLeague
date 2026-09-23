import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) var appState
    @State private var step: OnboardingStep = .welcome

    /// Onboarding step order (V2.1, post World Championship).
    ///
    /// The tournament ended July 2026 and all 48 countries are inactive in
    /// prod (mig 079). Until Sept 2026 step 3 still forced a WC country pick
    /// before the club (audit 2026-09, §4). The club is the primary entity
    /// again and is mandatory; the country picker survives only in Settings,
    /// season-gated by WCSeason.isVisible, for the next tournament.
    ///
    /// 0.  Welcome
    /// 1.  Her name
    /// 2.  His name
    /// 3.  PL club             — primary entity, mandatory (up to 2)
    /// 4.  Tier selection      — dedication level
    /// 5.  Notification ask    — system permission #1
    /// 6.  Calendar opt-in     — system permission #2
    /// 7.  Meet team           — entityId from the club
    /// 8.  Meet the boss       — manager card
    /// 9.  How it works        — closing pitch (scenarios)
    /// 10. (completion)        — MainTabView
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case herName
        case hisName
        case plTeamOptional
        // ONB-5: a `footballKnowledge` step used to sit here, asking her to
        // self-rate before she had seen anything. It was pulled from the flow
        // because nothing read the answer, and the view was kept "parked" for
        // a reintroduction that never came. Deleted 2026-09-23; git has it.
        case tierSelection
        case notificationPrompt
        case calendar
        case meetTeam
        case meetManager
        case howItWorks
    }

    /// The entity MeetTeamView + MeetManagerView load: the club picked at
    /// step 3, or a country if an existing install somehow has one and no
    /// club. The "arsenal" fallback only fires if the flow advanced without
    /// either, which OptionalPLTeamView prevents (Continue needs a pick).
    private var meetEntityId: String {
        if let id = appState.selectedTeam?.rawValue ?? appState.selectedCountry?.rawValue {
            return id
        }
        #if DEBUG
        assertionFailure("MeetTeam reached without a club selected — flow ordering broken")
        #endif
        return "arsenal"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots + back button row
                HStack {
                    if step != .welcome {
                        Button {
                            if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
                                step = prev
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.hotRose)
                        }
                    } else {
                        Spacer().frame(width: 14)
                    }

                    Spacer()

                    ProgressDotsView(
                        totalSteps: OnboardingStep.allCases.count,
                        currentStep: step.rawValue
                    )

                    Spacer()

                    // Balance the back button width
                    Spacer().frame(width: 14)
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 12)

                // Screen content
                switch step {
                case .welcome:
                    WelcomeView { step = .herName }
                case .herName:
                    HerNameView { step = .hisName }
                case .hisName:
                    HisNameView { step = .plTeamOptional }
                case .plTeamOptional:
                    OptionalPLTeamView { step = .tierSelection }
                case .tierSelection:
                    TierSelectionView { step = .notificationPrompt }
                case .notificationPrompt:
                    NotificationPromptView { step = .calendar }
                case .calendar:
                    CalendarOptInView { step = .meetTeam }
                case .meetTeam:
                    MeetTeamView(entityId: meetEntityId) { step = .meetManager }
                case .meetManager:
                    MeetManagerView(entityId: meetEntityId) { step = .howItWorks }
                case .howItWorks:
                    HowItWorksView { completeOnboarding() }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    /// Final completion: marks contexts as viewed, registers the APNs token
    /// with the (now-final) team + country + tier, and flips the onboarding
    /// flag.
    ///
    /// Token registration is deferred until here (rather than the
    /// NotificationPromptView step) because we want a single canonical POST
    /// after all the user's choices are locked in.
    private func completeOnboarding() {
        // Mark all contexts the user might land on as viewed so unread badges
        // don't pop with false positives on first feed render.
        if let country = appState.selectedCountry {
            UnreadTracker.shared.markViewed(.country(country))
        }
        if let team = appState.selectedTeam {
            UnreadTracker.shared.markViewed(.team(team))
        }
        UnreadTracker.shared.markViewed(.everyoneTalking)

        // V1.3: MeetTeam + MeetManager cards now cover what SeasonPrimer used
        // to show (table verdict, form summary, manager) — primer ends up
        // saying things the user already read. Mark it seen so RootView skips
        // straight to MainTabView.
        appState.hasSeenSeasonPrimer = true

        // The canonical token POST lives in NotificationService
        // .handleTokenRegistration, which guards on hasCompletedOnboarding (APNs
        // may deliver the token mid-onboarding, before tier/team/country are
        // final). Set the flag first, then let NotificationService own the
        // registration — one code path for the full follow-set (arrays + scope),
        // no duplicated body here.
        appState.hasCompletedOnboarding = true
        NotificationService.shared.reregisterForFollowChange()
        // ONB-3: cover the case where the APNs token hasn't been delivered yet
        // (slow network / sim) — redrive so registration happens this session.
        NotificationService.shared.redriveTokenIfNeeded()
        // Force-flush the whole onboarding set (names + team + country + tier
        // + flag) to disk NOW. UserDefaults writes are async; without this, a
        // user who finishes onboarding and immediately force-quits before
        // cfprefsd flushes loses every field and re-onboards next launch.
        appState.persistNow()
    }
}
