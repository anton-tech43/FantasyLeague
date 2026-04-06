import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var items: [ContentItem] = []
    @State private var isLoading = true
    @State private var hasError = false
    @State private var offset = 0
    @State private var canLoadMore = true
    @State private var freshnessCardDismissed = false
    @State private var hasAutoExpanded = false

    private let pageSize = 20

    private var isOffSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 6 && month <= 8
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isLoading && items.isEmpty {
                loadingView
            } else if items.isEmpty && hasError {
                errorView
            } else if items.isEmpty {
                emptyView
            } else {
                feedContent
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: "teamPage") {
                    HStack(spacing: 6) {
                        Text(appState.selectedTeam?.shortName ?? "Goal Digger")
                            .font(.detailTitle)
                            .foregroundColor(.textOnDark)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textOnDark.opacity(0.5))
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: "settings") {
                    Image(systemName: "gearshape")
                        .foregroundColor(.textOnDark.opacity(0.7))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadInitial() }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                // Freshness card
                if !freshnessCardDismissed, let card = freshnessCard {
                    card
                        .onTapGesture {
                            withAnimation { freshnessCardDismissed = true }
                        }
                        .transition(.opacity)
                }

                ForEach(items) { item in
                    NavigationLink(value: item.id) {
                        ContentCard(item: item, appState: appState)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: navigationPath.count)
                    .onAppear {
                        if item.id == items.suffix(3).first?.id {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .refreshable { await refresh() }
        .background(Color.appBackground)
    }

    // MARK: - Freshness States

    @ViewBuilder
    private var freshnessCard: some View {
        if let latest = items.first {
            let age = Date().timeIntervalSince(latest.publishedAt)
            let hours = age / 3600
            let teamName = appState.selectedTeam?.shortName ?? "your team"

            if hours < 12 {
                // State 1: Fresh — no card needed
                EmptyView()
            } else if hours < 72 {
                // State 2: Caught up
                FreshnessCard(
                    icon: "checkmark.circle",
                    iconColor: .green,
                    title: "You're all caught up",
                    message: "Nothing new for \(teamName) right now. We'll ping you when something happens."
                )
            } else if hours < 336 { // 14 days
                // State 3: Quiet period
                FreshnessCard(
                    icon: "moon.zzz",
                    iconColor: .textTertiary,
                    title: "Quiet week for \(teamName)",
                    message: "Not much happening right now. We'll let you know when there's something worth talking about."
                )
            } else if isOffSeason {
                // State 5: Off-season (June-August)
                FreshnessCard(
                    icon: "sun.max",
                    iconColor: .tierGold,
                    title: "Season's over!",
                    message: "The Premier League is on summer break. Enjoy the peace and quiet — we'll be back in August.\n\n(Transfer rumours might still pop up though)"
                )
            } else {
                // State 4: Extended silence
                FreshnessCard(
                    icon: "pause.circle",
                    iconColor: .textTertiary,
                    title: "The Premier League is on a break",
                    message: "No matches or major news right now. We'll wake up when things kick off again."
                )
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Layout.cardSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding(.horizontal, Layout.screenPadding)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Text("Something went wrong")
                .font(.feedHeadline)
                .foregroundColor(.textOnDark.opacity(0.7))
            Text("Pull down to try again.")
                .font(.onboardingBody)
                .foregroundColor(.textTertiary)
        }
    }

    private var emptyView: some View {
        EmptyStateView(teamName: appState.selectedTeam?.shortName ?? "your team")
    }

    // MARK: - Data Loading

    private func loadInitial() async {
        // Show cached data immediately
        let cached = CacheService.shared.fetchCachedFeed(
            teamId: appState.selectedTeam?.rawValue ?? "",
            in: modelContext
        )
        if !cached.isEmpty {
            items = cached
            isLoading = false
        }

        // Then fetch fresh
        await refresh()

        // Purge old cache
        CacheService.shared.purgeOldItems(in: modelContext)

        // Screen 8: auto-expand first item on initial launch after onboarding
        if !hasAutoExpanded, let firstItem = items.first {
            hasAutoExpanded = true
            navigationPath.append(firstItem.id)
        }
    }

    private func refresh() async {
        guard let teamId = appState.selectedTeam?.rawValue else { return }
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: 0)
            items = fetched
            offset = fetched.count
            canLoadMore = fetched.count == pageSize
            hasError = false
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            if items.isEmpty {
                #if DEBUG
                let mockItems = MockData.feed.filter { $0.teamId == teamId }
                if !mockItems.isEmpty {
                    items = mockItems
                } else {
                    hasError = true
                }
                #else
                hasError = true
                #endif
            }
        }
        isLoading = false
        freshnessCardDismissed = false
    }

    private func loadMore() async {
        guard canLoadMore, let teamId = appState.selectedTeam?.rawValue else { return }
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: offset)
            items.append(contentsOf: fetched)
            offset += fetched.count
            canLoadMore = fetched.count == pageSize
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            // Silent — existing items remain
        }
    }
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

struct SkeletonCard: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.shimmer)
                    .frame(width: 70, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.shimmer)
                    .frame(width: 50, height: 14)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.shimmer)
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.shimmer)
                .frame(width: 200, height: 16)
        }
        .cardStyle()
        .overlay(
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.05), .clear],
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
