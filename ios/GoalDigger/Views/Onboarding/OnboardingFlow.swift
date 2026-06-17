import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) var appState
    @State private var step: OnboardingStep = .welcome

    /// Onboarding step order (V2.0 — World Cup first restructure).
    ///
    /// Marketing in May/June 2026 pivots to the World Cup. A meaningful
    /// share of new users will be WC-curious people who don't follow the
    /// Premier League at all. The flow lands on country selection as the
    /// primary anchor and offers PL as optional after.
    ///
    /// 0.  Welcome
    /// 1.  Her name
    /// 2.  His name
    /// 3.  Country selection   — primary entity (WC 2026 national team)
    /// 4.  Optional PL team    — skippable
    /// 5.  Tier selection      — dedication level
    /// 6.  Notification ask    — system permission #1
    /// 7.  Calendar opt-in     — system permission #2
    /// 8.  Meet team           — entityId from country (or club if no country)
    /// 9.  Meet the boss       — manager card
    /// 10. How it works        — closing pitch (scenarios)
    /// 11. (completion)        — MainTabView
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case herName
        case hisName
        case countrySelection
        case plTeamOptional
        // ONB-5: `footballKnowledge` step removed from the flow until the signal
        // is actually used (planned: drive content depth / glossary verbosity).
        // FootballKnowledgeView + AppState.footballKnowledgeLevel are kept (parked)
        // so reintroduction is a one-line re-add here. See AUDIT_FINDINGS.md ONB-5.
        case tierSelection
        case notificationPrompt
        case calendar
        case meetTeam
        case meetManager
        case howItWorks
    }

    /// Whichever entity the user actually has — country first, then team.
    /// Used by MeetTeamView + MeetManagerView to know which team_page to
    /// load. The fallback "arsenal" only fires if the user reached MeetTeam
    /// with neither set, which the flow prevents (country is mandatory at
    /// step 3); it's a defensive default to avoid crashes.
    private var meetEntityId: String {
        if let id = appState.selectedCountry?.rawValue ?? appState.selectedTeam?.rawValue {
            return id
        }
        #if DEBUG
        // Reaching this branch means OnboardingFlow advanced past
        // CountrySelectionView without a country picked AND past
        // OptionalPLTeamView without a team — flow ordering is broken.
        // Crash loud in DEBUG; production sessions get the arsenal fallback
        // to avoid a crash they can't recover from.
        assertionFailure("MeetTeam reached without country or team selected — flow ordering broken")
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
                    HisNameView { step = .countrySelection }
                case .countrySelection:
                    CountrySelectionView(allowsSecond: true) { step = .plTeamOptional }
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

/// "How much football do you already know?" — a 3-level self-rating.
/// ⏸️ PARKED (ONB-5): currently NOT in the onboarding flow — removed to cut a
/// friction step that gathered a signal nothing used. Kept here, ready to
/// reintroduce once it drives behaviour (planned: content depth / glossary
/// verbosity by level). To re-add: restore `case footballKnowledge` in
/// OnboardingStep + the switch case, and point OptionalPLTeamView at it.
private struct FootballKnowledgeView: View {
    @Environment(AppState.self) var appState
    let onContinue: () -> Void

    private struct Level: Identifiable {
        let id: Int
        let title: String
        let body: String
    }

    private var levels: [Level] {
        [
            .init(id: 1, title: "I don't know anything",
                  body: "Total newcomer. You're here for \(appState.pObject), not the football."),
            .init(id: 2, title: "I know the basic rules",
                  body: "You get how the game works, but not \(appState.pPossessive) team or the players."),
            .init(id: 3, title: "Rules, \(appState.pPossessive) team, some players",
                  body: "You know the rules, \(appState.pPossessive) team, and a few of the players by name.")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How much football\ndo you already know?")
                        .font(.onboardingTitle)
                        .foregroundColor(.textOnDark)
                    Text("No wrong answer. It just helps us pitch things at the right level.")
                        .font(.onboardingBody)
                        .foregroundColor(.textOnDark.opacity(0.8))
                }
                .padding(.top, 24)

                VStack(spacing: Layout.cardSpacing) {
                    ForEach(levels) { level in
                        levelCard(level)
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func levelCard(_ level: Level) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appState.footballKnowledgeLevel = level.id
            onContinue()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(level.title)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Text(level.body)
                    .font(.jakarta(15, weight: .regular))
                    .foregroundColor(.textSecondaryOnCard)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
