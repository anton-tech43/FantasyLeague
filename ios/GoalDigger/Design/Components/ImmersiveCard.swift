import SwiftUI

/// Full-screen two-zone immersive card for the feed.
/// Zone 1 (65%): dark content area with headline + analogy/context + "press for more" hint
/// Zone 2 (35%): rose (or gold) talking point area with scroll indicator
struct ImmersiveCard: View {
    let item: ContentItem
    let feedContext: FeedContext
    let appState: AppState
    let cardHeight: CGFloat
    let feedPosition: Int
    let isYourMove: Bool
    let onZone1Tap: () -> Void
    let onZone2Tap: () -> Void

    init(
        item: ContentItem,
        feedContext: FeedContext,
        appState: AppState,
        cardHeight: CGFloat,
        feedPosition: Int = 0,
        isYourMove: Bool = false,
        onZone1Tap: @escaping () -> Void = {},
        onZone2Tap: @escaping () -> Void = {}
    ) {
        self.item = item
        self.feedContext = feedContext
        self.appState = appState
        self.cardHeight = cardHeight
        self.feedPosition = feedPosition
        self.isYourMove = isYourMove
        self.onZone1Tap = onZone1Tap
        self.onZone2Tap = onZone2Tap
    }

    // MARK: - Card variant

    private var isGoldVariant: Bool {
        item.type == .matchday || (feedContext == .everyoneTalking && item.worthKnowing)
    }

    private var zone2Background: Color {
        isGoldVariant ? .gold : .hotRose
    }

    private var zone2TextColor: Color {
        .black
    }

    // MARK: - Content

    private var headline: String {
        if case .everyoneTalking = feedContext {
            // Everyone context: use immersive headline falling back to neutral headline
            return item.immersiveHeadline ?? item.everyoneTalkingHeadline ?? item.headline.lowercased()
        }
        return item.immersiveHeadline ?? item.headline.lowercased()
    }

    /// The competition, unless the headline already says it. A card reading
    /// "atletico tomorrow. champions league. 7pm kickoff." does not need a
    /// CHAMPIONS LEAGUE strap above it; a card reading "out. on penalties."
    /// does, and that is the one she cannot place.
    private var competitionLabel: String? {
        guard let label = item.cupBadgeLabel else { return nil }
        return headline.localizedCaseInsensitiveContains(label) ? nil : label
    }

    private var contextLine: String? {
        // Personalise in both contexts. The shared feed has no boyfriend, but a
        // line that reached it carrying "[his name]" would render the raw token
        // — personalise() resolves it to the relationship noun instead.
        guard let raw = item.displayContext, !raw.isEmpty else { return nil }
        let personalised = appState.personalise(raw)
        return personalised.isEmpty ? nil : personalised
    }

    private var talkingPoint: String {
        if case .everyoneTalking = feedContext {
            // The shared "Football" feed is not about her partner, so it must
            // NOT fall back to the personal talking point. 57 World Cup cards
            // did exactly that and rendered "Ask him what they need from their
            // next game." to people browsing a neutral feed. An empty zone is
            // honest; a line addressed to a relationship this feed knows
            // nothing about is not.
            return item.everyoneTalkingTalkingPoints?.first ?? ""
        }
        return appState.personalise(item.regularTalkingPoints.first ?? "")
    }

    // MARK: - Share

    /// Text package shared by the bottom-right ShareLink on the immersive
    /// card. Combines headline + analogy + talking point + a soft attribution.
    /// Multi-line so it pastes cleanly into iMessage / WhatsApp.
    private var shareText: String {
        var lines: [String] = []
        lines.append(headline)
        if let context = contextLine, !context.isEmpty {
            lines.append("")
            lines.append(context)
        }
        lines.append("")
        lines.append("\(zone2Label) \(talkingPoint)")
        lines.append("")
        lines.append("via GoalDigger")
        return lines.joined(separator: "\n")
    }

    // MARK: - Zone 2 label rotation

    private var zone2Label: String {
        if isYourMove {
            return "Your move:"
        }
        if item.type == .matchday {
            return matchdayTimeLabel
        }
        if feedContext == .everyoneTalking && item.worthKnowing {
            return "Worth knowing:"
        }
        if case .everyoneTalking = feedContext {
            let labels = ["The chat:", "Everyone's saying:", "Drop this:", "Talk about it:", "Conversation starter:"]
            return labels[feedPosition % labels.count]
        }
        // Team NEWS cards
        let labels = ["Top talking point:", "Say this:", "Drop this:", "Your opener:", "Use this:"]
        return labels[feedPosition % labels.count]
    }

    private var matchdayTimeLabel: String {
        guard let kickoff = item.kickoffTime else { return "Today:" }
        let hour = Calendar.current.component(.hour, from: kickoff)
        if hour >= 17 { return "Tonight:" }
        if hour >= 12 { return "This afternoon:" }
        return "Today:"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            zone1
                .frame(height: cardHeight * Layout.immersiveZone1Ratio)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { onZone1Tap() }
            zone2
                .frame(height: cardHeight * Layout.immersiveZone2Ratio)
                .contentShape(Rectangle())
                .onTapGesture { onZone2Tap() }
        }
        .frame(height: cardHeight)
        .clipped()
    }

    // MARK: - Zone 1 (65%)

    private var zone1: some View {
        ZStack(alignment: .bottomLeading) {
            Color.deepMauve

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Which competition, when it is not the league. This is the
                // default feed, and without it "sunderland out. on penalties."
                // gives no clue whether that was a cup, Europe or a Saturday —
                // which is the one question cup coverage exists to answer.
                if let competition = competitionLabel {
                    Text(competition)
                        .font(.feedBadge)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(.hotRose)
                        .padding(.bottom, 10)
                }

                // Headline
                Text(headline)
                    .font(.immersiveHeadline)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                    .foregroundColor(.warmWhite)

                // Context/analogy line — the "girl reference". The whole thing
                // has to land or the wit dies, so no truncation. We let it wrap
                // and use minimumScaleFactor as the safety valve for very long
                // analogies on smaller devices.
                if let context = contextLine, !context.isEmpty {
                    Text(context)
                        .font(.immersiveContext)
                        .foregroundColor(.warmWhite)
                        .padding(.top, 12)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }

                Spacer()

                // Press hint
                Text("Press for more info and things to say")
                    .font(.immersiveHint)
                    .foregroundColor(.warmWhite.opacity(0.45))
                    .padding(.bottom, 16)
            }
            .padding(20)
        }
        .overlay(
            // Rose border on three sides only — top, left, right. Open at the
            // bottom so there's no visible seam between zone 1 (dark) and
            // zone 2 (pink). Drawing a full Rectangle stroke leaves a faint
            // line at the boundary and reads as a "border around the pink".
            GeometryReader { proxy in
                Path { path in
                    let inset: CGFloat = 2.5
                    let w = proxy.size.width
                    let h = proxy.size.height
                    path.move(to: CGPoint(x: inset, y: h))
                    path.addLine(to: CGPoint(x: inset, y: inset))
                    path.addLine(to: CGPoint(x: w - inset, y: inset))
                    path.addLine(to: CGPoint(x: w - inset, y: h))
                }
                .stroke(Color.hotRose, lineWidth: 5)
            }
        )
    }

    // MARK: - Zone 2 (35%)

    private var zone2: some View {
        ZStack {
            zone2Background

            // Anchor the label + talking point to the TOP of the pink zone
            // (no leading Spacer). This pushes the text right below the
            // dark/pink seam so it lands cleanly above the tab bar instead
            // of getting partially covered by it.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    // Top row: rotating label on the left, share button on
                    // the right. The share button has to live up here (not
                    // bottom-right of zone 2) because the bottom of zone 2
                    // sits behind the translucent tab bar — anything tappable
                    // there is invisible and ungrabbable.
                    HStack(alignment: .firstTextBaseline) {
                        Text(zone2Label)
                            .font(.jakarta(20, weight: .bold))
                        Spacer()
                        // Share the full card (headline + analogy + talking
                        // point + attribution) as a text package she can
                        // paste into iMessage / a group chat. ShareLink
                        // consumes the tap so the parent zone2 onTapGesture
                        // (which opens the detail view) doesn't also fire.
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(zone2TextColor)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Share this card")
                    }
                    Text(talkingPoint)
                        .font(.jakarta(20, weight: .mediumItalic))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Scroll indicator stays glued to the bottom (lives behind
                // the tab bar where its translucency lets it hint through).
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                        Text("scroll")
                            .font(.jakarta(12, weight: .medium))
                    }
                    .foregroundColor(zone2TextColor.opacity(0.8))
                    Spacer()
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .foregroundColor(zone2TextColor)
    }
}
