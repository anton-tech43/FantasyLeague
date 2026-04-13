import SwiftUI

struct TeamPageView: View {
    let teamId: String
    @Environment(AppState.self) var appState
    @State private var content: TeamPageContent?
    @State private var playerCards: [PlayerCard] = []
    @State private var isLoading = true
    @State private var hasError = false
    @State private var presentedPlayer: PlayerCard?

    private var hisNameOrHis: String {
        appState.hisName.isEmpty ? "His" : appState.hisName + "'s"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let content {
                ScrollView {
                    VStack(spacing: Layout.cardSpacing) {
                        // Club badge + name header
                        VStack(spacing: 12) {
                            Image(appState.selectedTeam?.badgeImageName ?? "")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(Color.feedDivider)
                                        .frame(width: 90, height: 90)
                                )

                            Text(appState.selectedTeam?.displayName ?? "")
                                .font(.detailTitle)
                                .foregroundColor(.textOnDark)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        let cards = content.cards

                        // Card 1: The basics
                        if let basics = cards.basics {
                            teamCard(title: "The basics", icon: "shield") {
                                infoLine(label: "Known as", value: basics.nickname)
                                infoLine(label: "Home ground", value: basics.stadium)
                                Text(appState.personalise(basics.funFact))
                                    .font(.feedTimestamp)
                                    .foregroundColor(.textSecondaryOnCard)
                                    .padding(.top, 4)
                            }
                        }

                        // Card 2: The manager
                        if let manager = cards.manager {
                            teamCard(title: "The manager", icon: "person") {
                                Text(manager.name)
                                    .font(.feedHeadline)
                                    .foregroundColor(.textPrimaryOnCard)
                                Text(appState.personalise(manager.summary))
                                    .font(.detailBody)
                                    .foregroundColor(.textPrimaryOnCard)
                                    .padding(.top, 2)
                            }
                        }

                        // Card 3: Ones to know
                        if let onesToKnow = cards.onesToKnow, !onesToKnow.players.isEmpty {
                            teamCard(title: "Ones to know", icon: "star") {
                                ForEach(Array(onesToKnow.players.prefix(3))) { player in
                                    let matchingCard = playerCards.first {
                                        $0.playerName.lowercased() == player.name.lowercased()
                                    }

                                    if let matchingCard {
                                        Button {
                                            presentedPlayer = matchingCard
                                        } label: {
                                            playerRow(player: player, tappable: true)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        playerRow(player: player, tappable: false)
                                    }
                                }
                            }
                        }

                        // Card 4: The rivalry
                        if let rivalry = cards.rivalry {
                            teamCard(title: "The rivalry", icon: "flame") {
                                Text(appState.personalise(rivalry.text))
                                    .font(.detailBody)
                                    .foregroundColor(.textPrimaryOnCard)
                            }
                        }

                        // Card 5: How they're doing
                        if let form = cards.form {
                            teamCard(title: "How they're doing", icon: "chart.line.uptrend.xyaxis") {
                                Text(form.leaguePositionLabel)
                                    .font(.feedHeadline)
                                    .foregroundColor(.textPrimaryOnCard)

                                FormDotsView(formString: form.recentForm)
                                    .padding(.vertical, 4)

                                Text(appState.personalise(form.formSummary))
                                    .font(.detailBody)
                                    .foregroundColor(.textSecondaryOnCard)
                            }
                        }

                        // Card 6: The season so far
                        if let season = cards.season {
                            teamCard(title: "The season so far", icon: "calendar") {
                                Text(appState.personalise(season.summary))
                                    .font(.detailBody)
                                    .foregroundColor(.textPrimaryOnCard)
                            }
                        }

                        // Card 7: Coming up
                        if let fixture = cards.nextFixture {
                            teamCard(title: "Coming up", icon: "sportscourt") {
                                HStack(spacing: 8) {
                                    Text(fixture.opponent)
                                        .font(.feedHeadline)
                                        .foregroundColor(.textPrimaryOnCard)
                                    Text(fixture.venue.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.3)
                                        .foregroundColor(.hotRose)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.hotRose.opacity(0.1))
                                        .cornerRadius(4)
                                }

                                Text(formattedFixtureDate(fixture.date))
                                    .font(.feedTimestamp)
                                    .foregroundColor(.textSecondaryOnCard)

                                if !fixture.preview.isEmpty {
                                    Text(appState.personalise(fixture.preview))
                                        .font(.detailBody)
                                        .foregroundColor(.textSecondaryOnCard)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.bottom, 40)
                }
            } else if isLoading {
                teamPageLoadingView
            } else if hasError {
                teamPageErrorView
            } else {
                // Warm placeholder for teams with no content yet
                warmPlaceholderView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadTeamPage() }
        .sheet(item: $presentedPlayer) { player in
            PlayerCardModal(player: player)
        }
    }

    // MARK: - Card builder

    @ViewBuilder
    private func teamCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.hotRose)
                Text(title.uppercased())
                    .font(.feedBadge)
                    .tracking(0.5)
                    .foregroundColor(.textSecondaryOnCard)
            }

            content()
        }
        .cardStyle()
    }

    @ViewBuilder
    private func infoLine(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.feedTimestamp)
                .foregroundColor(.textSecondaryOnCard)
            Text(value)
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
        }
    }

    @ViewBuilder
    private func playerRow(player: TopPlayer, tappable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(player.name)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Text(player.position)
                    .font(.feedTimestamp)
                    .foregroundColor(.textSecondaryOnCard)
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondaryOnCard)
                }
            }
            if let oneLiner = player.oneLiner {
                Text(appState.personalise(oneLiner))
                    .font(.feedTimestamp)
                    .foregroundColor(.textSecondaryOnCard)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Form dots

    private func formattedFixtureDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: isoDate) else { return isoDate }

        let display = DateFormatter()
        display.dateFormat = "EEEE d MMM, h:mma"
        display.amSymbol = "am"
        display.pmSymbol = "pm"
        return display.string(from: date)
    }

    // MARK: - Loading state

    private var teamPageLoadingView: some View {
        VStack(spacing: Layout.cardSpacing) {
            Circle()
                .fill(Color.feedDivider)
                .frame(width: 80, height: 80)
                .padding(.top, 16)

            ForEach(0..<5, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding(.horizontal, Layout.screenPadding)
    }

    // MARK: - Error state

    private var teamPageErrorView: some View {
        VStack(spacing: 16) {
            Text("Couldn't load \(hisNameOrHis.lowercased()) team right now.")
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
            Button {
                Task { await loadTeamPage() }
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

    // MARK: - Warm placeholder

    private var warmPlaceholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 32))
                .foregroundColor(.hotRose.opacity(0.6))
            Text("We're getting \(hisNameOrHis.lowercased()) team ready. Check back in a moment.")
                .font(.feedHeadline)
                .foregroundColor(.textSecondaryOnCard)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .padding(.horizontal, Layout.screenPadding)
    }

    // MARK: - Data loading with cache

    private func loadTeamPage() async {
        isLoading = true
        hasError = false

        // Check cache first
        if let cached = TeamPageCache.load(teamId: teamId) {
            content = cached.content
            isLoading = false

            // Fetch player cards in parallel with fresh data
            async let freshContent = fetchFromNetwork()
            async let players = fetchPlayerCards()

            playerCards = await players

            if let fresh = await freshContent {
                content = fresh
                TeamPageCache.save(content: fresh, teamId: teamId)
            }
            // If network fails, keep showing cache (even if stale)
            return
        }

        // No cache — fetch from network
        do {
            let fetched = try await APIClient.shared.fetchTeamPage(teamId: teamId)
            if let fetched {
                content = fetched
                TeamPageCache.save(content: fetched, teamId: teamId)
                playerCards = await fetchPlayerCards()
            } else {
                // Row exists but no content — try mock data in DEBUG
                #if DEBUG
                if let mock = MockData.teamPage(for: teamId) {
                    content = mock
                } else {
                    // No data at all — show warm placeholder (not error)
                    content = nil
                }
                #endif
            }
        } catch {
            // Network failed, no cache — try mock in DEBUG, else error
            #if DEBUG
            if let mock = MockData.teamPage(for: teamId) {
                content = mock
            } else {
                hasError = true
            }
            #else
            hasError = true
            #endif
        }
        isLoading = false
    }

    private func fetchFromNetwork() async -> TeamPageContent? {
        try? await APIClient.shared.fetchTeamPage(teamId: teamId)
    }

    private func fetchPlayerCards() async -> [PlayerCard] {
        (try? await APIClient.shared.fetchPlayerCards(teamId: teamId)) ?? []
    }
}

// MARK: - Form Dots View

struct FormDotsView: View {
    let formString: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(formString.enumerated()), id: \.offset) { _, char in
                Circle()
                    .fill(dotColor(for: char))
                    .frame(width: 8, height: 8)
            }
            Spacer()
        }
    }

    private func dotColor(for result: Character) -> Color {
        switch result {
        case "W": return .hotRose
        case "D": return .mutedText
        case "L": return Color.red.opacity(0.6)
        default: return .mutedText.opacity(0.3)
        }
    }
}
