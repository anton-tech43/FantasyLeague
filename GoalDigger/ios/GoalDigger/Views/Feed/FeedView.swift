import SwiftUI

struct FeedView: View {
    @Environment(AppState.self) private var appState
    @State private var items: [ContentItem] = []
    @State private var isLoading = true
    @State private var hasError = false
    @State private var selectedItem: ContentItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appBackground.ignoresSafeArea()

                if isLoading && items.isEmpty {
                    loadingView
                } else if hasError && items.isEmpty {
                    errorView
                } else if items.isEmpty {
                    emptyView
                } else {
                    feedContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(appState.selectedTeam?.shortName ?? "Goal Digger")
                        .font(Theme.detailTitle)
                        .foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedItem) { item in
                ContentDetailView(item: item)
            }
        }
        .task {
            await loadMockData()
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: Theme.cardSpacing) {
                // "Caught up" card if needed
                if let freshness = contentFreshness {
                    freshnessCard(freshness)
                }

                ForEach(items) { item in
                    ContentCard(item: item)
                        .onTapGesture {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            selectedItem = item
                        }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, Theme.elementSpacing)
        }
        .refreshable {
            await loadMockData()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: Theme.cardSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, Theme.elementSpacing)
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundStyle(Theme.textTertiary)

            Text("No updates yet")
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textSecondary)

            Text("We'll let you know when something happens with \(appState.selectedTeam?.shortName ?? "your team").")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
    }

    // MARK: - Error State

    private var errorView: some View {
        VStack(spacing: Theme.elementSpacing) {
            Text("Something went wrong")
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textSecondary)

            Text("Pull down to try again.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Content Freshness

    private enum Freshness {
        case caughtUp
        case quietWeek
    }

    private var contentFreshness: Freshness? {
        guard let latest = items.first?.publishedAt else { return nil }
        let hours = Date().timeIntervalSince(latest) / 3600
        if hours >= 12 && hours < 72 { return .caughtUp }
        if hours >= 72 { return .quietWeek }
        return nil
    }

    private func freshnessCard(_ freshness: Freshness) -> some View {
        Group {
            switch freshness {
            case .caughtUp:
                VStack(spacing: Theme.elementSpacing) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.accentGreen)

                    Text("You're all caught up")
                        .font(Theme.feedHeadline)
                        .foregroundStyle(Theme.textSecondary)

                    Text("Nothing new for \(appState.selectedTeam?.shortName ?? "your team") right now. We'll ping you when something happens.")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.cardPadding)
                .frame(maxWidth: .infinity)
                .background(Theme.feedDivider)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

            case .quietWeek:
                VStack(spacing: Theme.elementSpacing) {
                    Text("Quiet week for \(appState.selectedTeam?.shortName ?? "your team")")
                        .font(Theme.feedHeadline)
                        .foregroundStyle(Theme.textSecondary)

                    Text("Not much happening right now. We'll let you know when there's something worth talking about.")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.cardPadding)
                .frame(maxWidth: .infinity)
                .background(Theme.feedDivider)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            }
        }
    }

    // MARK: - Data Loading

    private func loadMockData() async {
        isLoading = true
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))

        if let team = appState.selectedTeam {
            items = MockData.items(for: team)
        } else {
            items = MockData.allItems
        }
        isLoading = false
    }
}

// MARK: - Skeleton Card

private struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.elementSpacing) {
            // Badge placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.shimmer)
                .frame(width: 60, height: 18)

            // Headline placeholder
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmer)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.shimmer)
                    .frame(width: 200, height: 16)
            }
        }
        .cardStyle()
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - ContentItem: Hashable for navigationDestination

extension ContentItem: Hashable {
    static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
