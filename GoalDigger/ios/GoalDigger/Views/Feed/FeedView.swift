import SwiftUI

// MARK: - FeedView
// Main feed screen — redesigned with personalized greeting and warm editorial feel.
//
// Design decisions for other agents:
// - Personalized time-of-day greeting using partner's name (e.g. "Good evening, Jake's playing tonight")
// - Gradient background (warm cream → warm beige) for depth
// - Empathetic freshness states ("All quiet tonight" instead of "No updates")
// - Staggered card entrance animations for polish
// - Data loading: API → SwiftData cache → MockData fallback (unchanged)

struct FeedView: View {
    @Environment(AppState.self) private var appState
    @State private var items: [ContentItem] = []
    @State private var isLoading = true
    @State private var hasError = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

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
                    NavigationLink(value: "settings") {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ContentItem.self) { item in
                ContentDetailView(item: item)
            }
            .navigationDestination(for: String.self) { value in
                if value == "settings" {
                    SettingsView()
                }
            }
        }
        .task {
            await loadContent()
        }
        .onChange(of: appState.deepLinkContentId) { _, newId in
            handleDeepLink(newId)
        }
        .onChange(of: appState.selectedTeam) { _, _ in
            Task { await loadContent() }
        }
    }

    // MARK: - Personalized Greeting

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }

        if let name = appState.userName {
            return "\(timeGreeting), \(name)"
        }
        return timeGreeting
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: Theme.cardSpacing) {
                // Personalized greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(Theme.greetingTitle)
                        .foregroundStyle(Theme.textPrimary)

                    if let partner = appState.partnerName, let team = appState.selectedTeam {
                        Text("Here's what's happening with \(partner)'s \(team.shortName)")
                            .font(Theme.feedTimestamp)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                if let freshness = contentFreshness {
                    freshnessCard(freshness)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        ContentCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .offset(y: 20).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(
                        .easeOut(duration: 0.4).delay(Double(index) * 0.08),
                        value: items.count
                    )
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, Theme.elementSpacing)
        }
        .refreshable {
            await loadContent()
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

    // MARK: - Empty State (empathetic)

    private var emptyView: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Image(systemName: "moon.stars")
                .font(.system(size: 50))
                .foregroundStyle(Theme.textTertiary)

            Text("All quiet tonight")
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textSecondary)

            Text("Nothing happening with \(appState.selectedTeam?.shortName ?? "your team") right now. We'll nudge you when there's something worth knowing.")
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

    // MARK: - Content Freshness (empathetic labels)

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

                    Text("Nothing new right now. Enjoy the peace!")
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
                    Text("Quiet spell")
                        .font(Theme.feedHeadline)
                        .foregroundStyle(Theme.textSecondary)

                    Text("Not much going on with \(appState.selectedTeam?.shortName ?? "your team"). We'll let you know when there's something worth talking about.")
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

    private func loadContent() async {
        guard let team = appState.selectedTeam else {
            items = MockData.allItems
            isLoading = false
            return
        }

        isLoading = true
        hasError = false

        // Try API first
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: team.rawValue)
            if !fetched.isEmpty {
                items = fetched
                await CacheService.shared.save(fetched)
                isLoading = false
                return
            }
        } catch {
            #if DEBUG
            print("[Feed] API fetch failed: \(error)")
            #endif
        }

        // Fall back to cache
        let cached = await CacheService.shared.load(teamId: team.rawValue)
        if !cached.isEmpty {
            items = cached
            isLoading = false
            return
        }

        // Fall back to mock data for development
        items = MockData.items(for: team)
        isLoading = false
    }

    // MARK: - Deep Link

    private func handleDeepLink(_ contentId: UUID?) {
        guard let contentId else { return }

        if let item = items.first(where: { $0.id == contentId }) {
            navigationPath.append(item)
            appState.deepLinkContentId = nil
            return
        }

        Task {
            if let item = try? await APIClient.shared.fetchItem(id: contentId) {
                navigationPath.append(item)
            }
            appState.deepLinkContentId = nil
        }
    }
}

// MARK: - Skeleton Card

private struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.elementSpacing) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.shimmer)
                .frame(width: 60, height: 18)

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
