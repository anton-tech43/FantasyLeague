import SwiftUI
import SwiftData

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
    /// Filled in when the team feed is empty AND the user is T2+. Lets us
    /// surface an Insider item ("Things he doesn't know") instead of the
    /// generic "nothing today" empty state, so the user always has
    /// something to read on opening the app. V1.1 task C1.
    @State private var emptyStateInsider: InsiderItem?
    /// LiveMatchCard surface (V1.1 task C5). When non-nil, a top-of-feed
    /// card renders showing live in-match commentary. Populated by a
    /// 60-second poll loop while the user is on the feed AND scenePhase
    /// is active. Cleared when the poll returns 204 (no live match).
    @State private var liveBrief: LiveMatchBrief?
    @State private var liveBriefPollTask: Task<Void, Never>?
    /// Saturday Quiz surface (V1.1 task C3). T3+ tier-gated. Fetched once
    /// on view load and on team change via the same `.task(id:)` that
    /// loads the live brief poll — no poll loop. The 36-hour freshness
    /// window lives server-side; iOS just renders whatever it gets back.
    @State private var currentQuiz: SaturdayQuiz?
    @AppStorage("hasSeenImmersiveBanner") private var hasSeenImmersiveBanner = false

    private let pageSize = 20
    private let screenHeight = UIScreen.main.bounds.height

    private var isOffSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 6 && month <= 8
    }

    /// Items for the active context
    private var displayItems: [ContentItem] {
        switch appState.activeContext {
        case .team: return teamItems
        case .everyoneTalking: return everyoneItems
        }
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
                    teamName: appState.selectedTeam?.shortName ?? "your team",
                    onBackToTeam: {
                        if let team = appState.selectedTeam {
                            switchContext(to: .team(team))
                        }
                    }
                )
            } else if displayItems.isEmpty {
                emptyView
            } else {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .task { await loadInitial() }
        .task(id: appState.selectedTeam?.rawValue) {
            // Live brief poll lifecycle. Kicks off on first appear and on
            // team change. The task body is the poll loop itself; it
            // exits when SwiftUI cancels the task (view disappear, id
            // change, app suspend). T1 users opt-out via TierGating.
            await runLiveBriefPoll()
        }
        .task(id: appState.selectedTeam?.rawValue) {
            // Saturday Quiz fetch (V1.1 task C3). Single-shot, not a poll
            // — the routine writes once a week and the server gates on a
            // 36-hour freshness window. T3+ only; T1/T2 users skip the
            // fetch entirely. Failure (network blip, 5xx) silently leaves
            // currentQuiz nil so the card simply doesn't render.
            await loadSaturdayQuiz()
        }
        .onChange(of: appState.selectedTeam) { oldTeam, newTeam in
            guard oldTeam != newTeam, newTeam != nil else { return }
            // Clear stale team data and reload for the new team
            teamItems = []
            teamOffset = 0
            teamCanLoadMore = true
            isLoading = true
            freshnessCardDismissed = false
            matchdayPlayers = []
            liveBrief = nil   // drop stale live card from prior team
            currentQuiz = nil // and stale quiz card for prior team
            Task { await loadTeamFeed() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // SwiftUI's .task auto-cancels on scenePhase background on
            // some iOS versions but not others; explicitly cancel here so
            // the 60s poll doesn't keep burning battery in the background.
            // .task(id:) re-fires on the next active phase via the
            // selectedTeam id, restarting the poll cleanly.
            if newPhase == .background {
                liveBriefPollTask?.cancel()
                liveBriefPollTask = nil
            }
        }
    }

    // MARK: - Live brief poll loop (V1.1 task C5)

    /// Polls the live-brief-current Edge Function every 60 seconds for the
    /// user's selected team. On 200 sets `liveBrief`; on 204 clears it.
    /// T1 users skip the poll entirely. Cancelled by SwiftUI when the
    /// view disappears or scenePhase transitions to .background.
    private func runLiveBriefPoll() async {
        // Cancel any prior task (defensive — .task(id:) should have done
        // this, but the explicit nil-out keeps our state honest).
        liveBriefPollTask?.cancel()

        guard TierGating.isAvailable(.matchDayLive, tier: appState.selectedTier),
              let teamId = appState.selectedTeam?.rawValue else {
            liveBrief = nil
            return
        }

        // Loop until cancelled. CancellationError exits cleanly.
        while !Task.isCancelled {
            do {
                let brief = try await APIClient.shared.fetchCurrentLiveBrief(teamId: teamId)
                liveBrief = brief
            } catch {
                // Network blip or backend hiccup. Don't blow away an
                // existing card on a transient error — keep the last
                // good value visible until the next successful poll.
                #if DEBUG
                print("⚠️ live brief poll error: \(error)")
                #endif
            }
            // 60s between polls. Task.sleep is cancellation-aware; if the
            // view disappears mid-sleep, this throws CancellationError and
            // we exit the loop.
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
        }
    }

    // MARK: - Saturday Quiz fetch (V1.1 task C3)

    /// Single-shot fetch for the weekend's Saturday Quiz. T3+ users only.
    /// The server returns 204 outside the 36-hour weekend window, which
    /// maps to nil here and hides the card. Failures leave `currentQuiz`
    /// untouched (either nil from this load, or the previously-fetched
    /// value if a transient error hit a refresh) so a hiccup never blows
    /// away a card the user was about to tap.
    private func loadSaturdayQuiz() async {
        guard TierGating.isAvailable(.saturdayQuiz, tier: appState.selectedTier),
              let teamId = appState.selectedTeam?.rawValue else {
            currentQuiz = nil
            return
        }
        do {
            currentQuiz = try await APIClient.shared.fetchCurrentQuiz(teamId: teamId)
        } catch {
            #if DEBUG
            print("⚠️ saturday quiz fetch error: \(error)")
            #endif
            // Leave currentQuiz at its existing value — don't blank a
            // visible card on a transient failure.
        }
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                    .stroke(Color.hotRose, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                aggregateUnreadBadge
            }
        }
    }

    @ViewBuilder
    private var pillIcon: some View {
        switch appState.activeContext {
        case .team(let team):
            Image(team.badgeImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        case .everyoneTalking:
            Image(systemName: "soccerball")
                .font(.system(size: 14))
                .foregroundColor(.hotRose)
        }
    }

    @ViewBuilder
    private var aggregateUnreadBadge: some View {
        let badgeText = UnreadTracker.shared.aggregateBadgeText(
            activeContext: appState.activeContext,
            teamItems: teamItems,
            everyoneItems: everyoneItems,
            selectedTeam: appState.selectedTeam
        )
        if let text = badgeText {
            Text(text)
                .font(.jakarta(11, weight: .bold))
                .foregroundColor(.warmWhite)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.hotRose)
                .clipShape(Capsule())
                .offset(x: 8, y: -8)
        }
    }

    // MARK: - Feed Content (switches between immersive and classic)

    @ViewBuilder
    private var feedContent: some View {
        // V1.1 task C5: LiveMatchCard renders as the first item INSIDE the
        // feed's scroll view so it scrolls away with content rather than
        // pinning to the top. See immersiveFeed and classic feed branches
        // for the prepend; both gate on `shouldShowLiveBrief` so the card
        // never appears for T1 users or in the "Everyone Talking" context.
        if appState.feedStyle == .immersive {
            immersiveFeed
        } else {
            VStack(spacing: 0) {
                if !hasSeenImmersiveBanner {
                    migrationBanner
                }
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        if shouldShowLiveBrief, let brief = liveBrief {
                            LiveMatchCard(brief: brief)
                                .padding(.horizontal, Layout.screenPadding)
                                .padding(.vertical, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        // SaturdayQuizCard sits below the live card — live
                        // takes priority during matches, quiz is the
                        // Saturday-morning surface that lasts the weekend.
                        if shouldShowQuiz, let quiz = currentQuiz {
                            SaturdayQuizCard(quiz: quiz)
                                .padding(.horizontal, Layout.screenPadding)
                                .padding(.vertical, 8)
                                .transition(.opacity)
                        }
                        ClassicFeedView(
                            items: displayItems,
                            feedContext: appState.activeContext,
                            appState: appState,
                            matchdayPlayers: matchdayPlayers,
                            freshnessCardDismissed: $freshnessCardDismissed,
                            isOffSeason: isOffSeason,
                            onLoadMore: { await loadMore() }
                        )
                    }
                }
                .refreshable { await refresh() }
            }
            .animation(.easeInOut(duration: 0.25), value: liveBrief?.id)
            .animation(.easeInOut(duration: 0.25), value: currentQuiz?.id)
        }
    }

    /// Whether the LiveMatchCard should render right now. Combines the
    /// data check (we have a brief), the tier gate, and the context check
    /// ("Everyone Talking" surface shouldn't show team-specific live).
    private var shouldShowLiveBrief: Bool {
        liveBrief != nil &&
        TierGating.isAvailable(.matchDayLive, tier: appState.selectedTier) &&
        appState.activeContext != .everyoneTalking
    }

    /// Whether the SaturdayQuizCard should render right now. T3+ only,
    /// data must be loaded, and the team context must be active (the
    /// quiz is team-specific). Sits BELOW LiveMatchCard in render order
    /// — during a live match the live card takes visual priority.
    private var shouldShowQuiz: Bool {
        currentQuiz != nil &&
        TierGating.isAvailable(.saturdayQuiz, tier: appState.selectedTier) &&
        appState.activeContext != .everyoneTalking
    }

    // MARK: - Immersive Feed

    private var immersiveFeed: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    // Live brief sits as the first item INSIDE the
                    // immersive scroll view so it scrolls away with the
                    // rest of the feed (V1.1 task C5). Placed BEFORE the
                    // ForEach so it sits above the "Your move" card. The
                    // animation modifier on the outer scroll view fades
                    // it in/out as the poll loop updates `liveBrief`.
                    if shouldShowLiveBrief, let brief = liveBrief {
                        LiveMatchCard(brief: brief)
                            .padding(.horizontal, Layout.screenPadding)
                            .padding(.vertical, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    // Quiz below live card. Same scroll-with-feed treatment
                    // as the live card so neither pins to the top of the
                    // immersive scroll view.
                    if shouldShowQuiz, let quiz = currentQuiz {
                        SaturdayQuizCard(quiz: quiz)
                            .padding(.horizontal, Layout.screenPadding)
                            .padding(.vertical, 8)
                            .transition(.opacity)
                    }
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        let isYourMove = index == 0 && appState.activeContext != .everyoneTalking
                        let isEveryoneCtx = appState.activeContext == .everyoneTalking

                        ImmersiveCard(
                            item: item,
                            feedContext: appState.activeContext,
                            appState: appState,
                            // Use full screen height (not geo height) so each card
                            // extends behind the tab bar — keeps the next card
                            // fully off-screen instead of letting a slice peek.
                            cardHeight: screenHeight,
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
                            if item.id == displayItems.suffix(3).first?.id {
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
        }
    }

    // MARK: - Migration Banner

    private var migrationBanner: some View {
        HStack {
            Text("New: immersive feed is now your default. Switch back in Settings anytime.")
                .font(.jakarta(12, weight: .regular))
                .foregroundColor(.charcoal)
            Spacer()
            Button {
                withAnimation { hasSeenImmersiveBanner = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.hotRose)
            }
        }
        .padding(12)
        .background(Color.softBlush)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - States

    @ViewBuilder
    private var loadingView: some View {
        if appState.feedStyle == .immersive {
            VStack(spacing: 0) {
                ImmersiveSkeletonCard(cardHeight: screenHeight * Layout.immersiveCardHeightRatio)
                ImmersiveSkeletonCard(cardHeight: screenHeight * Layout.immersiveCardHeightRatio)
            }
        } else {
            VStack(spacing: Layout.cardSpacing) {
                YourMoveSkeletonCard()
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, Layout.screenPadding)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Text("Something went wrong")
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
            Text("We'll try again in a sec.")
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
        // T2+ users with an insider item available get a useful card to
        // read instead of the generic "nothing today" empty state. T1 users
        // and teams without an insider row fall back to the original empty
        // state. Fetched in loadTeamFeed once teamItems is confirmed empty.
        if TierGating.isAvailable(.insiderCard, tier: appState.selectedTier),
           let insider = emptyStateInsider {
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
            EmptyStateView(teamName: appState.selectedTeam?.shortName ?? "your team")
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

        UnreadTracker.shared.markViewed(appState.activeContext)
        appState.activeContext = context
        UnreadTracker.shared.markViewed(context)
        freshnessCardDismissed = false

        // Load data for new context if empty
        Task {
            switch context {
            case .team:
                if teamItems.isEmpty { await loadTeamFeed() }
            case .everyoneTalking:
                if everyoneItems.isEmpty { await loadEveryoneFeed() }
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitial() async {
        // Set initial context from selected team
        if let team = appState.selectedTeam {
            appState.activeContext = .team(team)
        }

        // Show cached data immediately
        let cached = CacheService.shared.fetchCachedFeed(
            teamId: appState.selectedTeam?.rawValue ?? "",
            in: modelContext
        )
        if !cached.isEmpty {
            teamItems = cached
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
        case .team: await loadTeamFeed()
        case .everyoneTalking: await loadEveryoneFeed()
        }
    }

    private func loadTeamFeed() async {
        guard let teamId = appState.selectedTeam?.rawValue else { return }
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: 0)
            // Sunday Brief (V1.1 C2) is T2+. Filter client-side so a T1
            // user never sees the card even if it slipped into the response.
            // Server-side push gating in notification-sender stops the
            // notification; this guard handles the feed render.
            teamItems = Self.applyTierFilter(fetched, tier: appState.selectedTier)
            teamOffset = fetched.count
            teamCanLoadMore = fetched.count == pageSize
            hasError = false
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
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
        // When the team feed is empty for a T2+ user, pull the latest
        // insider item BEFORE flipping isLoading to false so the UI never
        // flashes the generic "nothing today" state. The fetch is
        // best-effort: failure leaves emptyStateInsider nil and emptyView
        // falls back to the generic state. Cleared when items come back.
        if teamItems.isEmpty,
           TierGating.isAvailable(.insiderCard, tier: appState.selectedTier),
           let teamId = appState.selectedTeam?.rawValue {
            let items = (try? await APIClient.shared.fetchInsiderItems(teamId: teamId, limit: 1)) ?? []
            emptyStateInsider = items.first
        } else {
            emptyStateInsider = nil
        }

        isLoading = false
        freshnessCardDismissed = false

        // Fetch player cards for matchday card if needed
        if teamItems.contains(where: { $0.type == .matchday }),
           let teamId = appState.selectedTeam?.rawValue {
            matchdayPlayers = (try? await APIClient.shared.fetchPlayerCards(teamId: teamId)) ?? []
        }
    }

    private func loadEveryoneFeed() async {
        // Show cached everyone items immediately if we have no data yet
        if everyoneItems.isEmpty {
            let cached = CacheService.shared.fetchCachedEveryoneFeed(in: modelContext)
            if !cached.isEmpty {
                everyoneItems = cached
            }
        }

        do {
            let fetched = try await APIClient.shared.fetchEveryoneFeed(limit: pageSize, offset: 0)
            everyoneItems = Self.applyTierFilter(fetched, tier: appState.selectedTier)
            everyoneOffset = fetched.count
            everyoneCanLoadMore = fetched.count == pageSize
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
        case .team:
            guard teamCanLoadMore, let teamId = appState.selectedTeam?.rawValue else { return }
            do {
                let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: teamOffset)
                teamItems.append(contentsOf: Self.applyTierFilter(fetched, tier: appState.selectedTier))
                teamOffset += fetched.count
                teamCanLoadMore = fetched.count == pageSize
                CacheService.shared.upsertItems(fetched, in: modelContext)
            } catch {
                #if DEBUG
                print("⚠️ loadMore failed: \(error.localizedDescription)")
                #endif
            }

        case .everyoneTalking:
            guard everyoneCanLoadMore else { return }
            do {
                let fetched = try await APIClient.shared.fetchEveryoneFeed(limit: pageSize, offset: everyoneOffset)
                everyoneItems.append(contentsOf: Self.applyTierFilter(fetched, tier: appState.selectedTier))
                everyoneOffset += fetched.count
                everyoneCanLoadMore = fetched.count == pageSize
                CacheService.shared.upsertItems(fetched, in: modelContext)
            } catch {
                #if DEBUG
                print("⚠️ loadMore failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Tier filter

    /// Strips content items above the user's tier. Sunday Brief (V1.1 C2)
    /// is T2+. Future tier-3-only types (Saturday Quiz, Player Dossier,
    /// Group-chat Prep) hook in here. Server-side gating handles push;
    /// this is the read/render side.
    static func applyTierFilter(_ items: [ContentItem], tier: Int) -> [ContentItem] {
        items.filter { item in
            switch item.type {
            case .news, .matchday:
                return true   // all tiers see the basics
            case .sundayBrief:
                return tier >= 2
            }
        }
    }
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

// MARK: - Skeleton Loading

struct YourMoveSkeletonCard: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                .fill(Color.warmWhite.opacity(0.15))
                .frame(width: 90, height: 22)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.warmWhite.opacity(0.15))
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.warmWhite.opacity(0.15))
                .frame(width: 200, height: 16)
        }
        .padding(Layout.cardPadding)
        .background(Color.hotRose)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            LinearGradient(
                colors: [.clear, Color.warmWhite.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerOffset)
        )
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
    }
}

struct SkeletonCard: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.hotRose.opacity(0.08))
                    .frame(width: 70, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.hotRose.opacity(0.08))
                    .frame(width: 50, height: 14)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.hotRose.opacity(0.08))
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.hotRose.opacity(0.08))
                .frame(width: 200, height: 16)
        }
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
        .overlay(
            LinearGradient(
                colors: [.clear, Color.hotRose.opacity(0.08), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerOffset)
        )
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
    }
}
