import SwiftUI

struct ContentDetailView: View {
    let contentId: UUID
    let scrollToTalkingPoints: Bool
    let isEveryoneContext: Bool
    @Environment(AppState.self) var appState
    @State private var item: ContentItem?
    @State private var isLoading: Bool
    @State private var onesToWatch: [PlayerCard] = []
    @State private var isBackstoryExpanded = false
    /// Level-3 info card ("To impress") is behind a + until she asks for it.
    @State private var showToImpress = false

    /// Preloaded item lets the feed render the detail view instantly without re-fetching.
    /// When opened from a push deep link, `preloadedItem` is nil and `loadItem()` fetches by id.
    init(contentId: UUID, scrollToTalkingPoints: Bool = false, isEveryoneContext: Bool = false, preloadedItem: ContentItem? = nil) {
        self.contentId = contentId
        self.scrollToTalkingPoints = scrollToTalkingPoints
        self.isEveryoneContext = isEveryoneContext
        self._item = State(initialValue: preloadedItem)
        self._isLoading = State(initialValue: preloadedItem == nil)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let item {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                            headerSection(item)
                            headlineSection(item)
                            if let scorers = item.scorers, !scorers.isEmpty {
                                scorersSection(scorers)
                            }
                            if let cards = item.infoCards, !cards.isEmpty {
                                infoCardsSection(cards)
                            }
                            talkingPointsSection(item)

                            if item.type == .matchday, let postMatch = item.postMatchCheatSheet {
                                postMatchSection(postMatch)
                            }

                            if item.type == .matchday, !onesToWatch.isEmpty {
                                Divider().background(Color.feedDivider)
                                OnesToWatchView(players: onesToWatch)
                            }

                            backstorySection(item)
                        }
                        .padding(.horizontal, Layout.screenPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .task {
                        if scrollToTalkingPoints {
                            try? await Task.sleep(for: .milliseconds(300))
                            withAnimation {
                                proxy.scrollTo("thingsToSay", anchor: .top)
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .tint(.hotRose)
            } else {
                // Empty/error state — never fall through to a blank screen.
                VStack(spacing: 16) {
                    Text("This one didn't load.")
                        .font(.feedHeadline)
                        .foregroundColor(.textOnDark)
                    Text("It might have been removed, or your connection dropped.")
                        .font(.onboardingBody)
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                    Button {
                        isLoading = true
                        Task { await loadItem() }
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
                .padding(Layout.screenPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if item != nil {
                ToolbarItem(placement: .topBarTrailing) { listenToolbarButton }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: "\(displayHeadline)\n\nvia GoalDigger"
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.hotRose)
                    }
                }
            }
        }
        .task { await loadItem() }
        .onDisappear { AudioPlayerService.shared.stop() }
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-gdShowImpress") { showToImpress = true } }
        #endif
    }

    // MARK: - Listen button

    @ViewBuilder
    private var listenToolbarButton: some View {
        let audio = AudioPlayerService.shared
        Button {
            switch audio.state {
            case .idle:    audio.speak("\(displayHeadline). \(displayBody)")
            case .playing: audio.pause()
            case .paused:  audio.resume()
            }
        } label: {
            Image(systemName: audio.state == .playing ? "pause.circle" : "play.circle")
                .foregroundColor(.hotRose)
        }
        .accessibilityLabel(audio.state == .playing ? "Pause listening" : "Listen")
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ item: ContentItem) -> some View {
        HStack {
            BadgeView(type: item.type, customLabel: item.cupBadgeLabel)
            Spacer()
            Text(item.publishedAt.relativeTimestamp)
                .font(.feedTimestamp)
                .foregroundColor(.textTertiary)
        }
    }

    // Context-aware content helpers
    private var displayHeadline: String {
        guard let item else { return "" }
        if isEveryoneContext {
            return item.everyoneTalkingHeadline ?? item.headline
        }
        return appState.personalise(item.headline)
    }

    private var displayBody: String {
        guard let item else { return "" }
        if isEveryoneContext {
            return item.everyoneTalkingBody ?? item.body
        }
        return appState.personalise(item.body)
    }

    private var displayTalkingPoints: [String] {
        guard let item else { return [] }
        if isEveryoneContext {
            return item.everyoneTalkingTalkingPoints ?? item.regularTalkingPoints
        }
        return item.regularTalkingPoints.map { appState.personalise($0) }
    }

    @ViewBuilder
    private func headlineSection(_ item: ContentItem) -> some View {
        // V2.0: team-crest header — renders 1 or 2 crests when the
        // content-generator (or routine) tagged the item with
        // affected_team_ids. >2 crests would crowd the detail view, so
        // those items render no header (matches the "everyone's talking"
        // cross-team UX). Legacy items with nil affectedTeamIds also
        // render no header — gracefully invisible.
        AffectedTeamsHeader(teamIds: item.affectedTeamIds)

        // The headline carries inline name explanations now (handled in the
        // generator prompt), so we don't need a separate factual sub-headline
        // here. The user already saw the analogy on the immersive card.
        Text(displayHeadline)
            .font(.jakarta(22, weight: .bold))
            .foregroundColor(.textOnDark)
            .padding(.top, 4)

        // Pre-match preview: lead with who's favoured (deterministic FIFA-rank
        // verdict the routine puts in match_result), so the reader gets the
        // "who's likely to win" answer the moment they open the brief.
        if item.previewFixtureId != nil,
           let verdict = item.matchResult, !verdict.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.hotRose)
                Text(verdict)
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.hotRose)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }

        Divider().background(Color.feedDivider)
    }

    @ViewBuilder
    /// Goal scorers + minutes for a post-game result article (075).
    private func scorersSection(_ scorers: [LiveMatchBrief.Scorer]) -> some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "Goals", icon: "soccerball")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(scorers) { scorer in
                    HStack(spacing: 10) {
                        Text(scorer.minute.isEmpty ? "·" : scorer.minute)
                            .font(.jakarta(13, weight: .bold))
                            .foregroundColor(.hotRose)
                            .frame(width: 46, alignment: .leading)
                        if let photoURL = scorer.photoURL {
                            AsyncImage(url: photoURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                        }
                        Text(scorer.player + (scorer.penalty == true ? " (pen)" : ""))
                            .font(.jakarta(15, weight: .regular))
                            .foregroundColor(.textPrimaryOnCard)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(scorer.team.uppercased())
                            .font(.jakarta(11, weight: .semiBold))
                            .tracking(0.5)
                            .foregroundColor(.textSecondaryOnCard)
                            .lineLimit(1)
                    }
                }
            }
            .padding(Layout.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
        }
    }

    /// What she needs to KNOW, above what she can SAY. Levels 1-2 render
    /// straight away; level 3 ("To impress") waits behind a +. Neutral facts
    /// by contract (post_news.sh rejects the sister voice here), so the same
    /// cards serve the club feed and the shared Football feed.
    @ViewBuilder
    private func infoCardsSection(_ cards: [InfoCard]) -> some View {
        let shown = cards.filter { !$0.isToImpress }
        let impress = cards.first { $0.isToImpress }
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "Good to know", icon: "info.circle")

            ForEach(shown) { card in
                InfoCardView(card: card, accent: .hotRose)
            }

            if let impress {
                if showToImpress {
                    InfoCardView(card: impress, accent: .gold)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showToImpress = true }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("To impress")
                                .font(.jakarta(14, weight: .semiBold))
                            Spacer()
                            Text("one more, for when he's listening")
                                .font(.jakarta(12, weight: .regular))
                                .foregroundColor(.gold.opacity(0.8))
                        }
                        .foregroundColor(.gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.gold.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gold.opacity(0.35), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show the to-impress card")
                }
            }
        }
    }

    private func talkingPointsSection(_ item: ContentItem) -> some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "Things to say", icon: "bubble.left")
                .id("thingsToSay")

            ForEach(Array(displayTalkingPoints.enumerated()), id: \.offset) { _, point in
                TalkingPointCard(text: point)
            }
        }
    }

    @ViewBuilder
    private func postMatchSection(_ postMatch: PostMatchCheatSheet) -> some View {
        Divider().background(Color.feedDivider)

        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "After the match", icon: "flag.checkered")

            // If they WIN
            PostMatchCard(
                label: "If they WIN:",
                text: appState.personalise(postMatch.ifTheyWin),
                tintColor: Color.winTint,
                barColor: Color.winBar
            )

            // If they LOSE
            PostMatchCard(
                label: "If they LOSE:",
                text: appState.personalise(postMatch.ifTheyLose),
                tintColor: Color.loseTint,
                barColor: Color.loseBar
            )
        }
    }

    @ViewBuilder
    private func backstorySection(_ item: ContentItem) -> some View {
        Divider().background(Color.feedDivider)

        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isBackstoryExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeaderView(title: "The backstory", icon: "book")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.hotRose)
                        .rotationEffect(.degrees(isBackstoryExpanded ? 90 : 0))
                }
            }

            if isBackstoryExpanded {
                GlossaryText(raw: displayBody)
                    .font(.detailBody)
                    .foregroundColor(.textOnDark.opacity(0.9))
                    .lineSpacing(6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Loading

    private func loadItem() async {
        // Skip the network round-trip when the feed already passed the item.
        // Re-fetch only when we arrived here from a push deep link (no preload).
        if item == nil {
            do {
                item = try await APIClient.shared.fetchItem(id: contentId)
            } catch {
                #if DEBUG
                // Fall back to mock data during development
                if let mock = MockData.feed.first(where: { $0.id == contentId }) {
                    item = mock
                }
                #endif
            }
        }
        isLoading = false

        // Fetch "ones to watch" player cards for matchday items
        if let item, item.type == .matchday {
            onesToWatch = (try? await APIClient.shared.fetchPlayerCards(teamId: item.teamId)) ?? []
        }
    }

}

// MARK: - Sub-components

struct SectionHeaderView: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title.uppercased())
                .font(.sectionHeader)
                .tracking(1)
        }
        .foregroundColor(.textTertiary)
    }
}

struct TalkingPointCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.hotRose)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.talkingPointText)
                    .foregroundColor(.textPrimaryOnCard)

                HStack(spacing: 4) {
                    Spacer()
                    CopyButton(text: text)
                    ShareLink(item: text, preview: SharePreview("From GoalDigger")) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.hotRose)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Share talking point")
                }
            }
            .padding(14)
        }
        .background(Color.hotRose.opacity(0.06))
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct PostMatchCard: View {
    let label: String
    let text: String
    let tintColor: Color
    let barColor: Color

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.feedBadge)
                    .textCase(.uppercase)
                    .foregroundColor(.textSecondaryOnCard)

                Text(text)
                    .font(.talkingPointText)
                    .foregroundColor(.textPrimaryOnCard)
            }
            .padding(14)
        }
        .background(tintColor)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

/// One info card. Level 1-2 rose accent, level 3 gold ("To impress").
/// A level-3 card with a `fixture` draws the two crests and the kickoff —
/// the match picture we can render without a photo we do not have.
struct InfoCardView: View {
    let card: InfoCard
    let accent: Color

    private var label: String {
        let base: String = {
            if let t = card.title, !t.isEmpty { return t }
            switch card.level {
            case 1: return "The gist"
            case 2: return "The wider picture"
            default: return "To impress"
            }
        }()
        // The competition sits in the label, not the crest strip — there it
        // truncated to "CHAMPIONS…" beside two crests and a kickoff.
        if let c = card.fixture?.competition, !c.isEmpty { return "\(base) · \(c)" }
        return base
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased())
                    .font(.feedBadge)
                    .tracking(1)
                    .foregroundColor(accent == .gold ? Color(hex: "#9A7B1A") : .textSecondaryOnCard)

                if let fixture = card.fixture {
                    fixtureStrip(fixture)
                }

                Text(card.text)
                    .font(.jakarta(15, weight: .regular))
                    .foregroundColor(.textPrimaryOnCard)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .background(accent.opacity(0.06))
        .background(Color.cardBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func fixtureStrip(_ f: InfoFixture) -> some View {
        HStack(spacing: 12) {
            side(name: f.home, crest: f.homeCrestURL)
            VStack(spacing: 2) {
                Text("v")
                    .font(.jakarta(13, weight: .bold))
                    .foregroundColor(.textSecondaryOnCard)
                if let k = f.kickoff {
                    Text(Self.kickoffFmt.string(from: k))
                        .font(.jakarta(11, weight: .medium))
                        .foregroundColor(.textSecondaryOnCard)
                }
            }
            side(name: f.away, crest: f.awayCrestURL)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func side(name: String, crest: URL?) -> some View {
        VStack(spacing: 4) {
            TeamCrestView(url: crest, size: 34)
            Text(name)
                .font(.jakarta(11, weight: .semiBold))
                .foregroundColor(.textPrimaryOnCard)
                .lineLimit(1)
                .frame(width: 72)
        }
    }

    private static let kickoffFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM, HH:mm"
        return f
    }()
}
