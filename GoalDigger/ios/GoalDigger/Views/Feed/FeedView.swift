import SwiftUI
import SwiftData

/// The main screen. A scrollable feed of content cards for the selected team.
struct FeedView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext
    @State private var viewModel = FeedViewModel()
    @State private var showSettings = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Group {
                    if viewModel.isInitialLoading && viewModel.items.isEmpty {
                        loadingState
                    } else if viewModel.hasError && viewModel.items.isEmpty {
                        errorState
                    } else if viewModel.items.isEmpty {
                        emptyState
                    } else {
                        feedContent
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(appState.selectedTeam?.shortName ?? "Goal Digger")
                        .font(.detailTitle)
                        .foregroundColor(.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .navigationDestination(for: ContentItem.self) { item in
                ContentDetailView(item: item)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                if let team = appState.selectedTeam {
                    await viewModel.loadFeed(teamId: team.rawValue, context: modelContext)
                }
            }
            .onChange(of: appState.deepLinkContentId) { _, newId in
                guard let id = newId else { return }
                appState.deepLinkContentId = nil
                handleDeepLink(id: id)
            }
        }
    }

    // MARK: - Deep Link Navigation

    private func handleDeepLink(id: UUID) {
        if let item = viewModel.items.first(where: { $0.id == id }) {
            navigationPath.append(item)
        } else {
            Task {
                if let item = try? await APIClient.shared.fetchItem(id: id) {
                    viewModel.items.insert(item, at: 0)
                    navigationPath.append(item)
                }
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                // Freshness status card (dismissible)
                if !viewModel.freshnessCardDismissed, let freshnessCard = viewModel.freshnessState {
                    FreshnessCardView(state: freshnessCard, teamName: appState.selectedTeam?.shortName ?? "")
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.25)) {
                                viewModel.freshnessCardDismissed = true
                            }
                        }
                }

                ForEach(viewModel.items) { item in
                    NavigationLink(value: item) {
                        ContentCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item == viewModel.items.last {
                            Task {
                                await viewModel.loadMore(teamId: appState.selectedTeam?.rawValue ?? "")
                            }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, Layout.elementSpacing)
        }
        .refreshable {
            if let team = appState.selectedTeam {
                await viewModel.refresh(teamId: team.rawValue, context: modelContext)
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: Layout.cardSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, Layout.elementSpacing)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No updates yet",
            message: "We'll let you know when something happens with \(appState.selectedTeam?.shortName ?? "your team")."
        )
    }

    private var errorState: some View {
        EmptyStateView(
            icon: "wifi.slash",
            title: "Something went wrong",
            message: "Pull down to try again."
        )
    }
}

// MARK: - Skeleton Loading Card

struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.shimmer)
                    .frame(width: 60, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.shimmer)
                    .frame(width: 40, height: 12)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.shimmer)
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.shimmer)
                .frame(width: 200, height: 16)
        }
        .cardStyle()
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Feed ViewModel

@Observable
class FeedViewModel {
    var items: [ContentItem] = []
    var isInitialLoading = false
    var isLoadingMore = false
    var hasError = false
    var freshnessState: FreshnessState?
    var freshnessCardDismissed = false

    private var currentOffset = 0
    private let pageSize = 20
    private var hasMorePages = true

    func loadFeed(teamId: String, context: ModelContext) async {
        isInitialLoading = true
        hasError = false
        freshnessCardDismissed = false

        // Purge stale cache on launch (items older than 30 days)
        await CacheService.shared.purgeOldItems(context: context)

        // Show cached items immediately (instant launch)
        let cached = await CacheService.shared.loadCachedItems(teamId: teamId, context: context)
        if !cached.isEmpty {
            items = cached.compactMap { $0.toContentItem() }
            isInitialLoading = false
            updateFreshnessState()
        }

        // Fetch fresh data from API
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: 0)
            items = fetched
            currentOffset = fetched.count
            hasMorePages = fetched.count >= pageSize
            await CacheService.shared.cacheItems(fetched, context: context)
            updateFreshnessState()
        } catch {
            hasError = items.isEmpty
        }

        isInitialLoading = false
    }

    func refresh(teamId: String, context: ModelContext) async {
        hasError = false
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: 0)
            items = fetched
            currentOffset = fetched.count
            hasMorePages = fetched.count >= pageSize
            await CacheService.shared.cacheItems(fetched, context: context)
            updateFreshnessState()
        } catch {
            hasError = items.isEmpty
        }
    }

    func loadMore(teamId: String) async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: currentOffset)
            items.append(contentsOf: fetched)
            currentOffset += fetched.count
            hasMorePages = fetched.count >= pageSize
        } catch {
            // Silently fail on pagination
        }
        isLoadingMore = false
    }

    private func updateFreshnessState() {
        guard let mostRecent = items.first?.publishedAt else {
            freshnessState = nil
            return
        }

        let hours = Date().timeIntervalSince(mostRecent) / 3600

        if hours < 12 {
            freshnessState = nil
        } else if hours < 72 {
            freshnessState = .caughtUp
        } else if hours < 336 {
            freshnessState = .quietWeek
        } else {
            freshnessState = .onBreak
        }
    }
}

// MARK: - Freshness States

enum FreshnessState {
    case caughtUp
    case quietWeek
    case onBreak
}

struct FreshnessCardView: View {
    let state: FreshnessState
    let teamName: String

    var body: some View {
        VStack(spacing: Layout.elementSpacing) {
            switch state {
            case .caughtUp:
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.accentGreen)
                Text("You're all caught up")
                    .font(.feedHeadline)
                    .foregroundColor(.textSecondary)
                Text("Nothing new for \(teamName) right now. We'll ping you when something happens.")
                    .font(.onboardingBody)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)

            case .quietWeek:
                Text("Quiet week for \(teamName)")
                    .font(.feedHeadline)
                    .foregroundColor(.textSecondary)
                Text("Not much happening right now. We'll let you know when there's something worth talking about.")
                    .font(.onboardingBody)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)

            case .onBreak:
                Text("The Premier League is on a break")
                    .font(.feedHeadline)
                    .foregroundColor(.textSecondary)
                Text("No matches or major news right now. We'll wake up when things kick off again.")
                    .font(.onboardingBody)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.feedDivider)
        .cornerRadius(Layout.cardCornerRadius)
    }
}

#Preview {
    FeedView()
        .environment(AppState.shared)
}
