import SwiftUI

struct TeamPageView: View {
    let teamId: String
    @Environment(AppState.self) var appState
    @State private var content: TeamPageContent?
    @State private var playerCards: [PlayerCard] = []
    @State private var latestInsider: InsiderItem?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var presentedPlayer: PlayerCard?
    @State private var expandedCard: TeamCardType?

    private enum TeamCardType: Hashable {
        case basics, manager, onesToKnow, rivalry, form, season, comingUp
    }

    private var hisNameOrHis: String {
        appState.hisName.isEmpty ? "His" : appState.hisName + "'s"
    }

    private var teamInitials: String {
        guard let team = appState.selectedTeam else { return "" }
        let words = team.displayName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
        return letters.joined()
    }

    /// Word-aware truncation. Plain `String.prefix(n)` cuts mid-word ("Chelsea
    /// and Brentford, Fulham are sandwiched betwe") which looks broken. This
    /// trims at the last whitespace at or before `maxChars` and appends an
    /// ellipsis. Falls back to the raw prefix if the text has no whitespace.
    private func truncateAtWord(_ text: String, maxChars: Int) -> String {
        if text.count <= maxChars { return text }
        let cutEnd = text.index(text.startIndex, offsetBy: maxChars)
        let head = text[..<cutEnd]
        if let lastSpace = head.lastIndex(where: { $0.isWhitespace }) {
            return String(text[..<lastSpace]) + "…"
        }
        return String(head) + "…"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let content {
                ScrollView {
                    VStack(spacing: 12) {
                        headerSection
                        cardsSection(content.cards)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            } else if isLoading {
                teamPageLoadingView
            } else if hasError {
                teamPageErrorView
            } else {
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.hotRose)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(teamInitials)
                        .font(.jakarta(24, weight: .bold))
                        .foregroundColor(.warmWhite)
                )

            Text(appState.selectedTeam?.displayName ?? "")
                .font(.jakarta(20, weight: .bold))
                .foregroundColor(.warmWhite)

            Text("\(hisNameOrHis) team")
                .font(.jakarta(14, weight: .regular))
                .foregroundColor(.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Cards section

    @ViewBuilder
    private func cardsSection(_ cards: TeamPageCards) -> some View {
        // Mood banner
        if let mood = cards.mood {
            TeamPageMoodBanner(mood: mood)
        }

        // THIS WEEK hero
        if let thisWeek = cards.thisWeek {
            TeamPageThisWeek(card: thisWeek)
        }

        // Card 1: The basics
        if let basics = cards.basics {
            TeamPageCard(
                title: "The basics",
                primaryText: basics.nickname,
                zone2Label: "Say this:",
                talkingPoint: basics.talkingPoint.map { appState.personalise($0) },
                isStatic: true,
                isExpanded: expandedCard == .basics,
                onTap: { toggleCard(.basics) },
                zone1Collapsed: {
                    Text(basics.stadium)
                        .font(.jakarta(13, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.7))
                        .lineLimit(1)
                },
                zone1Expanded: {
                    VStack(alignment: .leading, spacing: 6) {
                        infoLine(label: "Known as", value: basics.nickname)
                        infoLine(label: "Home ground", value: basics.stadium)
                        Text(appState.personalise(basics.funFact))
                            .font(.jakarta(13, weight: .regular))
                            .foregroundColor(.warmWhite.opacity(0.7))
                            .padding(.top, 4)
                    }
                }
            )
        }

        // Card 2: The manager
        if let manager = cards.manager {
            TeamPageCard(
                title: "The manager",
                primaryText: manager.name,
                zone2Label: "Drop this:",
                talkingPoint: manager.talkingPoint.map { appState.personalise($0) },
                isStatic: true,
                isExpanded: expandedCard == .manager,
                onTap: { toggleCard(.manager) },
                zone1Collapsed: { EmptyView() },
                zone1Expanded: {
                    Text(appState.personalise(manager.summary))
                        .font(.jakarta(14, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.9))
                        .padding(.top, 2)
                }
            )
        }

        // Card 3: Ones to know
        if let onesToKnow = cards.onesToKnow, !onesToKnow.players.isEmpty {
            TeamPageCard(
                title: "Ones to know",
                primaryText: onesToKnow.players.prefix(3).map(\.name).joined(separator: ", "),
                zone2Label: "Your opener:",
                talkingPoint: onesToKnow.talkingPoint.map { appState.personalise($0) },
                isExpanded: expandedCard == .onesToKnow,
                onTap: { toggleCard(.onesToKnow) },
                zone1Collapsed: { EmptyView() },
                zone1Expanded: {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(onesToKnow.players.prefix(3))) { player in
                            // Always tappable. The matchingCard lookup is
                            // diacritic-folded + lowercased contains so:
                            //   - "Saka" (OnesToKnow curated short name) matches
                            //     "Bukayo Saka" (routine pulls full name from
                            //     API-Football squad / training data)
                            //   - "Odegaard" (OnesToKnow) matches "Martin Ødegaard"
                            //     (routine, with diacritic) — without folding,
                            //     the Ø ≠ O code-point mismatch would break it
                            // If no row exists yet, we build a stub PlayerCard
                            // with empty summary — PlayerCardModal then renders
                            // the .empty branch ("lands Sunday"). T1/T2 users
                            // get the .locked teaser. Tap is always allowed so
                            // discovery works on every tier.
                            let matchingCard = playerCards.first { card in
                                let cardName = card.playerName.folding(
                                    options: [.diacriticInsensitive, .caseInsensitive],
                                    locale: .current
                                )
                                let onesName = player.name.folding(
                                    options: [.diacriticInsensitive, .caseInsensitive],
                                    locale: .current
                                )
                                return cardName.contains(onesName) || onesName.contains(cardName)
                            }

                            Button {
                                presentedPlayer = matchingCard ?? PlayerCard(
                                    teamId: teamId,
                                    playerName: player.name,
                                    position: player.position,
                                    age: nil,
                                    summary: "",
                                    vibe: nil,
                                    form: nil
                                )
                            } label: {
                                playerRow(player: player, tappable: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            )
        }

        // Card 4: The rivalry
        if let rivalry = cards.rivalry {
            TeamPageCard(
                title: "The rivalry",
                primaryText: truncateAtWord(appState.personalise(rivalry.text), maxChars: 50),
                zone2Label: "Use this:",
                talkingPoint: rivalry.talkingPoint.map { appState.personalise($0) },
                isStatic: true,
                isExpanded: expandedCard == .rivalry,
                onTap: { toggleCard(.rivalry) },
                zone1Collapsed: { EmptyView() },
                zone1Expanded: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.personalise(rivalry.text))
                            .font(.jakarta(14, weight: .regular))
                            .foregroundColor(.warmWhite.opacity(0.9))

                        if let intensity = cards.rivalryIntensity {
                            TeamPageRivalryMeter(intensity: intensity)
                        }
                    }
                }
            )
        }

        // Card 5: How they're doing
        if let form = cards.form {
            TeamPageCard(
                title: "How they're doing",
                primaryText: form.leaguePositionLabel,
                zone2Label: "Say this:",
                talkingPoint: form.talkingPoint.map { appState.personalise($0) },
                isExpanded: expandedCard == .form,
                onTap: { toggleCard(.form) },
                zone1Collapsed: {
                    TeamPageFormDots(recentForm: form.recentForm, isExpanded: false)
                },
                zone1Expanded: {
                    VStack(alignment: .leading, spacing: 6) {
                        TeamPageFormDots(recentForm: form.recentForm, isExpanded: expandedCard == .form)

                        Text(appState.personalise(form.formSummary))
                            .font(.jakarta(14, weight: .regular))
                            .foregroundColor(.warmWhite.opacity(0.9))
                    }
                }
            )
        }

        // Card 6: The season so far
        if let season = cards.season {
            TeamPageCard(
                title: "The season so far",
                primaryText: truncateAtWord(appState.personalise(season.summary), maxChars: 50),
                zone2Label: "Drop this:",
                talkingPoint: season.talkingPoint.map { appState.personalise($0) },
                isExpanded: expandedCard == .season,
                onTap: { toggleCard(.season) },
                zone1Collapsed: { EmptyView() },
                zone1Expanded: {
                    Text(appState.personalise(season.summary))
                        .font(.jakarta(14, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.9))
                }
            )
        }

        // Card 7: Coming up / Post-match
        if showPostMatch, let postMatch = content?.cards.postMatch {
            postMatchCard(postMatch)
        } else if let fixture = cards.nextFixture {
            comingUpCard(fixture)
        }

        // Card 8 (T2+ only): "Things he doesn't know" — niche stat /
        // anecdote / history / oddity refreshed daily by the gd-insider
        // cloud routine. Gating: TierGating.isAvailable(.insiderCard,
        // tier:) returns true for tier 2 and 3 — T1 users never see it.
        // Latest item only; the History page (if we add one) would show the
        // last N.
        if TierGating.isAvailable(.insiderCard, tier: appState.selectedTier),
           let insider = latestInsider {
            VStack(alignment: .leading, spacing: 8) {
                Text("THINGS HE DOESN'T KNOW")
                    .font(.sectionHeader)
                    .tracking(1)
                    .foregroundColor(.mutedText)
                    // Align with the InsiderCard's inner padding (14pt
                    // around the rose bar + content) so the tracker label
                    // sits visually flush with the card's content edge.
                    .padding(.leading, 14)
                InsiderCard(item: insider)
            }
            .padding(.top, 8)
        }

        // Freshness line
        if let text = cards.freshnessText {
            Text(text)
                .font(.jakarta(12, weight: .regular))
                .foregroundColor(.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    // MARK: - Coming up card

    @ViewBuilder
    private func comingUpCard(_ fixture: NextFixtureCard) -> some View {
        TeamPageCard(
            title: "Coming up",
            primaryText: "\(fixture.opponent) (\(fixture.venue.uppercased()))",
            zone2Label: comingUpLabel(for: fixture.date),
            talkingPoint: fixture.talkingPoint.map { appState.personalise($0) },
            isExpanded: expandedCard == .comingUp,
            onTap: { toggleCard(.comingUp) },
            zone1Collapsed: {
                Text(formattedFixtureDate(fixture.date))
                    .font(.jakarta(13, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.7))
                    .lineLimit(1)
            },
            zone1Expanded: {
                VStack(alignment: .leading, spacing: 6) {
                    TeamPageCountdown(targetDate: fixture.date)

                    if !fixture.preview.isEmpty {
                        Text(appState.personalise(fixture.preview))
                            .font(.jakarta(14, weight: .regular))
                            .foregroundColor(.warmWhite.opacity(0.9))
                            .padding(.top, 2)
                    }
                }
            }
        )
    }

    // MARK: - Post-match card

    @ViewBuilder
    private func postMatchCard(_ postMatch: TeamPostMatchCard) -> some View {
        let tintColor: Color? = {
            switch postMatch.state {
            case .win: return Color.hotRose.opacity(0.06)
            case .loss: return Color.red.opacity(0.04)
            case .draw: return nil
            }
        }()

        let label: String = {
            switch postMatch.state {
            case .win: return "Say this:"
            case .loss: return "Tonight:"
            case .draw: return "Ask him:"
            }
        }()

        TeamPageCard(
            title: postMatch.state == .win ? "After the win" : postMatch.state == .loss ? "After the loss" : "After the draw",
            primaryText: truncateAtWord(appState.personalise(postMatch.text), maxChars: 50),
            zone2Label: label,
            talkingPoint: appState.personalise(postMatch.talkingPoint),
            isExpanded: expandedCard == .comingUp,
            onTap: { toggleCard(.comingUp) },
            tintColor: tintColor,
            zone1Collapsed: { EmptyView() },
            zone1Expanded: {
                Text(appState.personalise(postMatch.text))
                    .font(.jakarta(14, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.9))
            }
        )
    }

    // MARK: - Helpers

    private func toggleCard(_ type: TeamCardType) {
        withAnimation(.spring(duration: 0.3)) {
            expandedCard = (expandedCard == type) ? nil : type
        }
    }

    private var showPostMatch: Bool {
        guard let pm = content?.cards.postMatch,
              let expires = Self.isoFormatter.date(from: pm.expiresAt)
        else { return false }
        return Date() < expires
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func comingUpLabel(for dateString: String) -> String {
        guard let date = Self.isoFormatter.date(from: dateString) else { return "Coming up:" }

        if Calendar.current.isDateInToday(date) {
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 17 ? "Tonight:" : "This afternoon:"
        }

        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysUntil <= 7 {
            let weekday = Calendar.current.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7 // Sun or Sat
            return isWeekend ? "This weekend:" : "This week:"
        }
        return "Coming up:"
    }

    @ViewBuilder
    private func infoLine(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.jakarta(12, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.5))
            Text(value)
                .font(.jakarta(14, weight: .bold))
                .foregroundColor(.warmWhite)
        }
    }

    @ViewBuilder
    private func playerRow(player: TopPlayer, tappable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(player.name)
                    .font(.jakarta(14, weight: .bold))
                    .foregroundColor(.warmWhite)
                Text(player.position)
                    .font(.jakarta(12, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.5))
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.warmWhite.opacity(0.5))
                }
            }
            if let oneLiner = player.oneLiner {
                Text(appState.personalise(oneLiner))
                    .font(.jakarta(12, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.7))
            }
        }
        .padding(.vertical, 2)
    }

    private func formattedFixtureDate(_ isoDate: String) -> String {
        guard let date = Self.isoFormatter.date(from: isoDate) else { return isoDate }

        let display = DateFormatter()
        display.dateFormat = "EEEE d MMM, h:mma"
        display.amSymbol = "am"
        display.pmSymbol = "pm"
        return display.string(from: date)
    }

    // MARK: - Loading state

    private var teamPageLoadingView: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.feedDivider)
                .frame(width: 64, height: 64)
                .padding(.top, 16)

            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.deepMauve.opacity(0.5))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.hotRose.opacity(0.2), lineWidth: 2)
                            .padding(1)
                    )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Error state

    private var teamPageErrorView: some View {
        VStack(spacing: 16) {
            Text("Couldn't load \(hisNameOrHis.lowercased()) team right now.")
                .font(.jakarta(15, weight: .semiBold))
                .foregroundColor(.warmWhite)
            Button {
                Task { await loadTeamPage() }
            } label: {
                Text("Try again")
                    .font(.jakarta(15, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.deepMauve)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.3), lineWidth: 2)
                .padding(1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Warm placeholder

    private var warmPlaceholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 32))
                .foregroundColor(.hotRose.opacity(0.6))
            Text("We're getting \(hisNameOrHis.lowercased()) team ready. Check back in a moment.")
                .font(.jakarta(15, weight: .medium))
                .foregroundColor(.warmWhite.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.deepMauve)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.3), lineWidth: 2)
                .padding(1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Data loading with cache

    private func loadTeamPage() async {
        isLoading = true
        hasError = false

        // Check cache first
        if let cached = TeamPageCache.load(teamId: teamId) {
            content = cached.content
            isLoading = false

            // Fetch player cards + latest insider item in parallel with fresh data
            async let freshContent = fetchFromNetwork()
            async let players = fetchPlayerCards()
            async let insider = fetchLatestInsider()

            playerCards = await players
            latestInsider = await insider

            if let fresh = await freshContent {
                content = fresh
                TeamPageCache.save(content: fresh, teamId: teamId)
            }
            return
        }

        // No cache — fetch from network
        do {
            let fetched = try await APIClient.shared.fetchTeamPage(teamId: teamId)
            if let fetched {
                content = fetched
                TeamPageCache.save(content: fetched, teamId: teamId)
                async let players = fetchPlayerCards()
                async let insider = fetchLatestInsider()
                playerCards = await players
                latestInsider = await insider
            } else {
                #if DEBUG
                if let mock = MockData.teamPage(for: teamId) {
                    content = mock
                } else {
                    content = nil
                }
                #endif
            }
        } catch {
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

    /// Fetches the most recent insider item for the current team. Returns
    /// nil on error or when the team has no items yet — caller treats both
    /// identically (no card rendered).
    private func fetchLatestInsider() async -> InsiderItem? {
        let items = (try? await APIClient.shared.fetchInsiderItems(teamId: teamId, limit: 1)) ?? []
        return items.first
    }
}
