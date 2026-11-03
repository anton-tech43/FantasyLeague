import SwiftUI
import SwiftData
import UserNotifications

struct FeedView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // Dual data sources
    @State private var teamItems: [ContentItem] = []
    @State private var everyoneItems: [ContentItem] = []

    // Per-context loading state
    @State private var isLoading = true
    @State private var hasError = false
    @State private var teamOffset = 0
    @State private var everyoneOffset = 0
    @State private var teamCanLoadMore = true
    @State private var everyoneCanLoadMore = true
    @State private var isLoadingMore = false
    @State private var freshnessCardDismissed = false
    @State private var matchdayPlayers: [PlayerCard] = []
    /// Filled in when the team feed is empty, for every tier. Lets us
    /// surface an Insider item ("Things he doesn't know") instead of the
    /// generic "nothing today" empty state, so the user always has
    /// something to read on opening the app. V1.1 task C1.
    @State private var emptyStateInsider: InsiderItem?
    /// LiveMatchCard surface (V1.1 task C5), polled by MainTabView for this
    /// feed's entity and shared with Matchday.
    @State private var live = LiveBriefPoller.shared
    private var liveBrief: LiveMatchBrief? { live.entityId == activeEntityId ? live.brief : nil }
    @State private var notificationStatus: UNAuthorizationStatus = .authorized
    /// When `loadInitial` last ran. `.task` fires on every re-appearance, back
    /// from a story included, and the reload replaced the list with page 1:
    /// past card 20 the rest vanished, and a story that landed while she read
    /// pushed every card down one, so she came back a card off (bug hunt
    /// 2026-11-03 U-C5). Coming back within five minutes keeps the list.
    // ponytail: past five minutes it still reloads page 1 and can move her;
    // the upgrade is a `.scrollPosition(id:)` anchor restored after the reload.
    @State private var loadedAt: Date?

    private let pageSize = 20
    private let screenHeight = UIScreen.main.bounds.height

    private var isOffSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 6 && month <= 8
    }

    /// The entity (club or country) the feed is showing (AppState.feedEntityId).
    private var activeEntityId: String? { appState.feedEntityId }

    /// Items for the active context
    private var displayItems: [ContentItem] {
        switch appState.activeContext {
        case .team, .country: return teamItems
        case .everyoneTalking: return everyoneItems
        }
    }

    /// Items for the scrolling list body.
    ///
    /// This used to subtract a hero item that WCNextMatchCard rendered above
    /// the list in the tournament context. Both went with that context on
    /// 2026-09-23; the name stays as the one the feed reads from.
    private var bodyItems: [ContentItem] { displayItems }

    private var activeTeam: Team? {
        if case .team(let team) = appState.activeContext { return team }
        return nil
    }


    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isLoading && displayItems.isEmpty {
                loadingView
            } else if displayItems.isEmpty && hasError {
                errorView
            } else if displayItems.isEmpty && appState.activeContext == .everyoneTalking {
                EveryoneEmptyStateCard(
                    cardHeight: screenHeight * Layout.immersiveCardHeightRatio,
                    teamName: appState.selectedTeam?.shortName
                        ?? (CountryFollowing.isEnabled ? appState.selectedCountry?.shortName : nil),
                    onBackToTeam: {
                        // iOS-9: fall back to a followed country for WC-only users
                        // (no club) so the button isn't a no-op. Only while
                        // country following is on: with it off a country context
                        // is invalid and the app repairs it away on foreground.
                        if let team = appState.selectedTeam {
                            switchContext(to: .team(team))
                        } else if CountryFollowing.isEnabled, let country = appState.selectedCountry {
                            switchContext(to: .country(country))
                        }
                    }
                )
            } else if displayItems.isEmpty && !shouldShowLiveBrief {
                emptyView
            } else {
                // With no items but a live match on, the feed
                // still renders: the live score must not hide behind
                // "Quiet on his end" (bug hunt 2026-10-27).
                feedContent
            }

            // Context switcher overlay
            if appState.isContextSwitcherOpen {
                ContextSwitcherView(
                    appState: appState,
                    teamItems: teamItems,
                    everyoneItems: everyoneItems,
                    onSelect: { context in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isContextSwitcherOpen = false
                        }
                        switchContext(to: context)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isContextSwitcherOpen = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(100)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                contextPill
            }
        }
        .settingsButton()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .task {
            // An empty or failed feed always reloads: a load cut short by a
            // tab switch must not leave the skeleton up for five minutes.
            if let loadedAt, !teamItems.isEmpty, !hasError,
               Date().timeIntervalSince(loadedAt) < 5 * 60 { return }
            await loadInitial()
            if !Task.isCancelled { loadedAt = Date() }
        }
        .task { await checkNotifications() }
        .onChange(of: activeEntityId) { _, newEntity in
            // Keyed on the entity `teamItems` belongs to, not selectedTeam
            // (.first): following [A, B] on B and removing B in Settings moves
            // the context to A while `.first` stays A, and the old trigger
            // never fired, so B's stories stayed up under A's name.
            // Clear stale entity data and reload for the new one.
            teamItems = []
            teamOffset = 0
            teamCanLoadMore = true
            freshnessCardDismissed = false
            matchdayPlayers = []
            emptyStateInsider = nil
            guard newEntity != nil else { return }
            isLoading = true
            Task { await loadTeamFeed() }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Re-fetch the feed on return so a "stale empty during the match"
            // view is replaced by the latest (e.g. the FT result). The live
            // brief poll restarts in MainTabView.
            if newPhase == .active && oldPhase == .background {
                Task { await refresh() }
            }
            // Back from iOS Settings: the banner goes the moment she turns
            // notifications on.
            if newPhase == .active { Task { await checkNotifications() } }
        }
    }

    // MARK: - Notifications-off banner

    /// The push is the product ("It only works if we can reach you"), so the
    /// feed says so when it cannot reach her, and says nothing otherwise.
    /// Settings keeps the same control for when she goes looking.
    private func checkNotifications() async {
        notificationStatus = await NotificationService.shared.checkNotificationStatus()
        #if DEBUG
        // `-gdNotificationsOff` shows the banner on a simulator that has
        // already granted notifications (simctl cannot revoke them).
        if ProcessInfo.processInfo.arguments.contains("-gdNotificationsOff") {
            notificationStatus = .denied
            bannerSnoozedUntil = 0
        }
        #endif
    }

    private var pushesOff: Bool {
        guard bannerSnoozedUntil < Date().timeIntervalSince1970 else { return false }
        return notificationStatus == .denied || (notificationStatus == .notDetermined && appState.hasCompletedOnboarding)
    }

    /// "Not now" hides the banner for two weeks: she may have turned them off
    /// on purpose, and a notice on every open would be nagging.
    @AppStorage("notificationsBannerSnoozedUntil") private var bannerSnoozedUntil: Double = 0

    private var notificationsOffBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notifications are off")
                .font(.jakarta(15, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("You'll miss the score as it happens and the heads-up before \(appState.pPossessive) next game.")
                .font(.jakarta(13, weight: .regular))
                .foregroundColor(.textPrimaryOnCard.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            // Side by side, or stacked when the text is too big for one row
            // ("Turn t…" at the accessibility sizes, bug hunt 2026-11-03 U-C9).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { bannerButtons }
                VStack(alignment: .leading, spacing: 4) { bannerButtons }
            }
            .padding(.top, 2)
        }
        .foregroundColor(.textPrimaryOnCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardBackground))
        // It sits above the paged feed, so at the largest sizes it would take
        // half the screen from the cards (which stop at .xxxLarge themselves).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
        .onAppear { Analytics.shared.log(.notificationsBanner, ["action": "shown"]) }
    }

    @ViewBuilder
    private var bannerButtons: some View {
            Button {
                Analytics.shared.log(.notificationsBanner, ["action": "turn_on"])
                Task {
                    if notificationStatus == .notDetermined {
                        _ = await NotificationService.shared.requestPermission()
                        appState.notificationPermissionRequested = true
                        await checkNotifications()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            } label: {
                Text("Turn them on")
                    .font(.jakarta(13, weight: .bold))
                    .foregroundColor(.warmWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.hotRose))
            }
            Button("Not now") {
                Analytics.shared.log(.notificationsBanner, ["action": "not_now"])
                bannerSnoozedUntil = Date().addingTimeInterval(14 * 24 * 3600).timeIntervalSince1970
            }
            .font(.jakarta(13, weight: .semiBold))
            .foregroundColor(.textPrimaryOnCard.opacity(0.7))
            .frame(minHeight: 44)
    }

    // MARK: - Context Pill

    private var contextPill: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.isContextSwitcherOpen.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                pillIcon
                Text(appState.activeContext.displayName)
                    .font(.detailTitle)
                    .foregroundColor(.textOnDark)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textOnDark.opacity(0.6))
                    .rotationEffect(.degrees(appState.isContextSwitcherOpen ? 180 : 0))
                // Inside the pill, after the chevron. It sat on the pill's
                // corner for four months and was clipped by the navigation bar
                // in every build ("9+" read as a sliver, 2026-09-16); nothing
                // inside the outline can be clipped.
                aggregateUnreadBadge
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                    .stroke(Color.hotRose, lineWidth: 1)
            )

        }
    }

    @ViewBuilder
    private var pillIcon: some View {
        switch appState.activeContext {
        case .team(let team):
            TeamCrestView(team: team, size: 16)
        case .country(let country):
            AsyncImage(url: country.crestURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.hotRose)
                }
            }
            .frame(width: 16, height: 16)
        case .everyoneTalking:
            Image(systemName: appState.activeContext.iconName)
                .font(.system(size: 14))
                .foregroundColor(.hotRose)
        }
    }

    @ViewBuilder
    private var aggregateUnreadBadge: some View {
        // FeedView holds ONE team/country list at a time (activeEntityId's).
        // UnreadTracker counts each context only over items whose teamId is
        // its own, so a followed club or country that is not loaded counts
        // zero instead of borrowing the loaded one's stories. The badge
        // under-reports for an unloaded context; it never mislabels.
        let badgeText = UnreadTracker.shared.aggregateBadgeText(
            activeContext: appState.activeContext,
            teamItems: teamItems,
            countryItems: teamItems,
            everyoneItems: everyoneItems,
            selectedTeams: appState.selectedTeams,
            selectedCountries: appState.selectedCountries
        )
        if let text = badgeText {
            Text(text)
                .font(.jakarta(11, weight: .bold))
                .foregroundColor(.warmWhite)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.hotRose)
                .clipShape(Capsule())
                .fixedSize()
        }
    }

    // MARK: - Feed Content

    // There used to be a second feed here. The Immersive/Classic switch was
    // taken out of Settings in May 2026 and nothing has been able to set
    // .classic since, so the whole else-arm below this line — ClassicFeedView,
    // ContentCard, MatchDayCard, YourMoveCard, two skeletons and a migration
    // banner whose copy told her to "switch back in Settings anytime" — has
    // been compiled into every build and unreachable from all of them.
    // Removed 2026-09-23.
    //
    // V1.1 task C5: LiveMatchCard renders as the first item INSIDE the feed's
    // scroll view so it scrolls away with content rather than pinning to the
    // top. It gates on `shouldShowLiveBrief` so the card never appears in the
    // "Everyone Talking" context.

    private var feedContent: some View { immersiveFeed }

    /// Whether the LiveMatchCard should render right now: we have a brief
    /// and the context is a club ("Everyone Talking" shouldn't show
    /// team-specific live). Every tier sees the score; the commentary under
    /// it is Match-fit and up (LiveMatchCard.showsProse).
    private var shouldShowLiveBrief: Bool {
        liveBrief != nil && appState.activeContext != .everyoneTalking
    }

    // MARK: - Immersive Feed

    private var immersiveFeed: some View {
        // The banner sits above the feed, not inside it, so the cards below
        // are sized to the space that is left and "Your move" still clears
        // the tab bar on the first card. It is a top safe-area inset, not a
        // row of a VStack: in a VStack the scroll view's frame started under
        // the banner while view-aligned paging measured from higher up, so a
        // swipe came to rest ~60 pt off a card with the next headline hidden
        // behind the banner (bug hunt 2026-11-03 U-C7). As an inset the
        // scroll view runs to the top like it does under the navigation bar,
        // and the cards page against the edge she can see.
        GeometryReader { geo in
          ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    // Live brief sits as the first item INSIDE the
                    // immersive scroll view so it scrolls away with the
                    // rest of the feed (V1.1 task C5). Placed BEFORE the
                    // ForEach so it sits above the "Your move" card. The
                    // animation modifier on the outer scroll view fades
                    // it in/out as the poll loop updates `liveBrief`.
                    if shouldShowLiveBrief, let brief = liveBrief {
                        LiveMatchCard(
                            brief: brief,
                            showsProse: TierGating.isAvailable(.matchDayLive, tier: appState.selectedTier),
                            isPaused: live.isPaused
                        )
                            .padding(.horizontal, Layout.screenPadding)
                            .padding(.vertical, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .id(Self.liveCardID)
                    }
                    ForEach(Array(bodyItems.enumerated()), id: \.element.id) { index, item in
                        let isYourMove = index == 0 && appState.activeContext != .everyoneTalking
                        let isEveryoneCtx = appState.activeContext == .everyoneTalking

                        ImmersiveCard(
                            item: item,
                            feedContext: appState.activeContext,
                            appState: appState,
                            // The visible feed plus the strip behind the tab bar:
                            // the card ends at the bottom of the screen, so the
                            // next card stays fully off-screen. It used to be the
                            // whole screen's height, which pushed the talking
                            // point under the tab bar by the height of the club
                            // pill above the feed.
                            cardHeight: geo.size.height + geo.safeAreaInsets.bottom,
                            bottomInset: geo.safeAreaInsets.bottom,
                            feedPosition: index,
                            isYourMove: isYourMove,
                            onZone1Tap: {
                                appState.deepLinkContentId = nil
                                navigateToDetail(item: item, scrollToTalkingPoints: false, isEveryoneContext: isEveryoneCtx)
                            },
                            onZone2Tap: {
                                appState.deepLinkContentId = nil
                                navigateToDetail(item: item, scrollToTalkingPoints: true, isEveryoneContext: isEveryoneCtx)
                            }
                        )
                        .onAppear {
                            if item.id == bodyItems.suffix(3).first?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .background(Color.deepMauve)
            .scrollContentBackground(.hidden)
            .refreshable { await refresh() }
            // A kickoff, goal or half-time push lands on the score, not on
            // whichever card she last left the feed on.
            .onChange(of: appState.pushTapTick) { _, _ in
                if shouldShowLiveBrief { proxy.scrollTo(Self.liveCardID, anchor: .top) }
            }
            #if DEBUG
            // `-gdFeedIndex N` lands on the Nth card once the feed has loaded,
            // so a screenshot can reach any card without a swipe (simctl cannot tap).
            .task(id: bodyItems.count) {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-gdFeedIndex"), i + 1 < args.count,
                   let n = Int(args[i + 1]), n < bodyItems.count {
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo(bodyItems[n].id, anchor: .top)
                }
            }
            #endif
          }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if pushesOff {
                notificationsOffBanner
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.vertical, 8)
                    .background(Color.appBackground)
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 0) {
            ImmersiveSkeletonCard(cardHeight: screenHeight * Layout.immersiveCardHeightRatio)
            ImmersiveSkeletonCard(cardHeight: screenHeight * Layout.immersiveCardHeightRatio)
        }
        .loadingSkeleton()
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Text("That didn't load.")
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
            Text("We couldn't load this just now. Give it another go.")
                .font(.onboardingBody)
                .foregroundColor(.textSecondaryOnCard)
            Button {
                Task { await refresh() }
            } label: {
                Text("Try again")
                    .font(.feedHeadline)
                    .foregroundColor(.warmWhite)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .padding(.horizontal, Layout.screenPadding)
    }

    @ViewBuilder
    private var emptyView: some View {
        // The country feed's own empty state (a World Championship countdown)
        // went with the retired tournament (council 2026-10-29).
        if let insider = emptyStateInsider {
            // Every tier gets one specific fact instead of the generic
            // "nothing today": a quiet week is when Light needs it most.
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("NO NEWS RIGHT NOW. WORTH KNOWING:")
                        .font(.sectionHeader)
                        .tracking(1)
                        .foregroundColor(.mutedText)
                        // 14pt aligns with the InsiderCard's inner padding
                        // around the rose bar — keeps tracker label flush
                        // with card content edge.
                        .padding(.leading, 14)
                    InsiderCard(item: insider)
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.top, 24)
            }
        } else {
            // Clubs without an insider row fall back to the original empty
            // state.
            // The club on screen, not her first one.
            EmptyStateView(teamName: activeTeam?.shortName ?? appState.selectedTeam?.shortName ?? "your team")
        }
    }

    // MARK: - Navigation Helper

    private func navigateToDetail(item: ContentItem, scrollToTalkingPoints: Bool, isEveryoneContext: Bool) {
        // Pass the full item along — the detail view renders it immediately, no re-fetch needed.
        // (Push-notification deep links go through a different path with no item available.)
        let dest = ContentDetailDestination(
            contentId: item.id,
            scrollToTalkingPoints: scrollToTalkingPoints,
            isEveryoneContext: isEveryoneContext,
            preloadedItem: item
        )
        NotificationCenter.default.post(
            name: .feedNavigateToDetail,
            object: dest
        )
    }

    // MARK: - Context Switching

    private func switchContext(to context: FeedContext) {
        // Save scroll position for current context
        // (handled automatically via @State — session only)

        let previous = appState.activeContext
        let previousEntity = activeEntityId
        UnreadTracker.shared.markViewed(appState.activeContext)
        appState.activeContext = context
        UnreadTracker.shared.markViewed(context)
        freshnessCardDismissed = false

        // Re-tapping the current context: nothing to reload.
        if previous == context { return }

        // Load data for the new context.
        Task {
            switch context {
            case .team, .country:
                // A different entity is cleared and reloaded by
                // onChange(of: activeEntityId), so `teamItems` can never show
                // the previous entity's stories (reported bug 2026-06-01).
                // The same entity (back from Everyone Talking) refreshes in
                // place; reloading it here as well raced two loads.
                if activeEntityId == previousEntity { await loadTeamFeed() }
            case .everyoneTalking:
                if everyoneItems.isEmpty { await loadEveryoneFeed() }
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitial() async {
        // NOTE: do NOT set appState.activeContext here. AppState.init()
        // establishes the initial context once at app launch; after that
        // the user owns it via ContextSwitcherView. FeedView is a reader,
        // not a writer. Previously this method unconditionally ran
        // `activeContext = .team(selectedTeam)` on every .task fire — which
        // meant a tab switch (His Team → Feed) silently overwrote the
        // user's switcher choice. If they picked Sweden, came back to the
        // feed, they'd see Arsenal again. Confirmed via plan investigation
        // 2026-05-18; see STATUS.md note.

        // Show cached data immediately — for the ACTIVE context's entity, not
        // always selectedTeam. Keying on selectedTeam flashed the old team's
        // cached feed when the user had switched to a country (or vice versa)
        // until the fresh fetch returned.
        let cacheEntityId = activeEntityId ?? ""
        let cached = CacheService.shared.fetchCachedFeed(
            teamId: cacheEntityId,
            in: modelContext
        )
        if !cached.isEmpty, teamItems.isEmpty {
            teamItems = Self.uniqued(cached)
            isLoading = false
        }

        // Then fetch fresh data for both contexts
        await loadTeamFeed()

        // Also pre-fetch everyone feed in background
        Task { await loadEveryoneFeed() }

        // Purge old cache
        CacheService.shared.purgeOldItems(in: modelContext)
    }

    private func refresh() async {
        switch appState.activeContext {
        case .team, .country: await loadTeamFeed()
        case .everyoneTalking: await loadEveryoneFeed()
        }
    }

    private func loadTeamFeed() async {
        // The entity comes from activeContext (see activeEntityId); returns
        // early when there is none. Captured BEFORE the await: a club switch or
        // a Settings change while the request is in flight changes
        // activeEntityId, and the stale response must not land in `teamItems`
        // under the new entity's name. The newer load owns the state then.
        guard let teamId = activeEntityId else { return }
        var isStale: Bool { activeEntityId != teamId }
        do {
            let page = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: 0)
            let fetched = page.items
            if isStale { return }
            teamItems = Self.uniqued(fetched)
            teamOffset = page.rows
            teamCanLoadMore = page.rows == pageSize
            hasError = false
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            if isStale { return }
            if teamItems.isEmpty {
                #if DEBUG
                let mockItems = MockData.feed.filter { $0.teamId == teamId }
                if !mockItems.isEmpty {
                    teamItems = mockItems
                } else {
                    hasError = true
                }
                #else
                hasError = true
                #endif
            }
        }
        // When the team feed is empty, pull the latest insider item BEFORE
        // flipping isLoading to false so the UI never flashes the generic
        // "nothing today" state. The fetch is best-effort: failure leaves
        // emptyStateInsider nil and emptyView falls back to the generic
        // state. Cleared when items come back. Skipped when the feed itself
        // failed: against a hung backend it doubled the wait before the
        // error showed (~20 s instead of ~10).
        // Use the ACTIVE entity (teamId, resolved above from activeContext),
        // not appState.selectedTeam — otherwise a country feed shows the
        // club's "things he doesn't know" (or nothing, for a WC-only user
        // with no club). Countries have their own insider rows. (bug 2026-06-01)
        if teamItems.isEmpty, !hasError {
            let items = (try? await APIClient.shared.fetchInsiderItems(teamId: teamId, limit: 1)) ?? []
            if isStale { return }
            emptyStateInsider = items.first
        } else {
            emptyStateInsider = nil
        }

        isLoading = false
        freshnessCardDismissed = false

        // Fetch player cards for matchday card if needed. Uses the active
        // entity (teamId) so a country matchday gets the country's players,
        // not the club's. (bug 2026-06-01)
        if teamItems.contains(where: { $0.type == .matchday }) {
            let players = (try? await APIClient.shared.fetchPlayerCards(teamId: teamId)) ?? []
            if isStale { return }
            matchdayPlayers = players
        }
    }

    private func loadEveryoneFeed() async {
        // Show cached everyone items immediately if we have no data yet
        if everyoneItems.isEmpty {
            let cached = CacheService.shared.fetchCachedEveryoneFeed(in: modelContext)
            if !cached.isEmpty {
                everyoneItems = Self.uniqued(cached)
            }
        }

        do {
            let page = try await APIClient.shared.fetchEveryoneFeed(limit: pageSize, offset: 0)
            let fetched = page.items
            everyoneItems = Self.uniqued(fetched)
            everyoneOffset = page.rows
            everyoneCanLoadMore = page.rows == pageSize
            // A failed club feed must not keep Football on "didn't load".
            if appState.activeContext == .everyoneTalking { hasError = false }
            // Cache everyone items alongside team items
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            #if DEBUG
            if everyoneItems.isEmpty {
                // Use mock items for everyone feed if available
                everyoneItems = MockData.feed.filter { $0.everyoneTalking }
            }
            #endif
        }
        if appState.activeContext == .everyoneTalking {
            isLoading = false
        }
    }

    private func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        switch appState.activeContext {
        case .team(let team):
            guard teamCanLoadMore else { return }
            await loadMoreEntity(teamId: team.rawValue)

        case .country(let country):
            guard teamCanLoadMore else { return }
            await loadMoreEntity(teamId: country.rawValue)

        case .everyoneTalking:
            guard everyoneCanLoadMore else { return }
            do {
                let page = try await APIClient.shared.fetchEveryoneFeed(limit: pageSize, offset: everyoneOffset)
                let fetched = page.items
                // Offset paging shifts when a story is published between
                // pages, so page N+1 can repeat the tail of page N. A repeated
                // id breaks ForEach(id:), so drop what is already shown.
                everyoneItems = Self.uniqued(everyoneItems + fetched)
                everyoneOffset += page.rows
                everyoneCanLoadMore = page.rows == pageSize
                CacheService.shared.upsertItems(fetched, in: modelContext)
            } catch {
                #if DEBUG
                print("⚠️ loadMore failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Shared paginated fetch for either a PL team or a WC country.
    private func loadMoreEntity(teamId: String) async {
        do {
            let page = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: teamOffset)
            let fetched = page.items
            // The context changed while this page was in flight: it belongs
            // to the previous entity, whose list has already been replaced.
            guard activeEntityId == teamId else { return }
            // Same de-dup as the Everyone feed above: offset paging can repeat ids.
            teamItems = Self.uniqued(teamItems + fetched)
            teamOffset += page.rows
            teamCanLoadMore = page.rows == pageSize
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            #if DEBUG
            print("⚠️ loadMore failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// First occurrence of each id, order kept. ForEach(id: \.element.id)
    /// misrenders (and logs) on a repeated id, which offset paging produces
    /// whenever a story lands between two page fetches.
    static func uniqued(_ items: [ContentItem]) -> [ContentItem] {
        var seen = Set<UUID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    static let liveCardID = "live-card"
}

// MARK: - Notification Name for Feed Navigation

extension Notification.Name {
    static let feedNavigateToDetail = Notification.Name("feedNavigateToDetail")
}

// MARK: - Freshness Card

struct FreshnessCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .padding(.bottom, 4)

            Text(title)
                .font(.feedHeadline)
                .foregroundColor(.textOnDark.opacity(0.7))

            Text(message)
                .font(.onboardingBody)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.feedDivider)
        .cornerRadius(Layout.cardCornerRadius)
    }
}
