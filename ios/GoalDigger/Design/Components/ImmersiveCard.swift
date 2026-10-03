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

    private func headlineText(size: CGFloat) -> some View {
        TightHeadline(text: headline, size: size)
            .accessibilityAddTraits(.isHeader)
    }

    /// The largest step at which the headline, tracked at -0.05 em, wraps
    /// into three lines or fewer at this width.
    static func headlineSize(_ text: String, width: CGFloat) -> CGFloat {
        for size: CGFloat in [64, 56, 48, 42, 36, 32] {
            guard let font = UIFont(name: "LeagueSpartan-Black", size: size) else { return 48 }
            let rect = NSAttributedString(string: text, attributes: TightHeadline.attributes(font: font, size: size))
                .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin], context: nil)
            if rect.height <= TightHeadline.lineHeight * size * 3 + 1 { return size }
        }
        return 32
    }

    var body: some View {
        VStack(spacing: 0) {
            // To VoiceOver zone 1 is one button that opens the story; zone 2
            // keeps its share button separate, so only its talking point
            // carries the button trait (see zone2).
            zone1
                .frame(height: cardHeight * Layout.immersiveZone1Ratio)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { onZone1Tap() }
                // Spelled out rather than .combine: the headline is a UILabel
                // (TightHeadline). Still a heading, so the rotor steps card
                // to card.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel([competitionLabel, headline, contextLine].compactMap { $0 }.joined(separator: ". "))
                .accessibilityHint("Press for more info and things to say")
                .accessibilityAddTraits([.isButton, .isHeader])
                .accessibilityAction { onZone1Tap() }
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
                // -50 tracking (-0.05 em): letters and the gaps between words
                // sit tighter (Anton, 2026-10-04). Fitted by stepping the size
                // down rather than minimumScaleFactor, which shrinks the glyphs
                // but not the tracking, so a long headline's letters collided.
                // Line height stays the font's own 0.92 em, already under 1.0.
                headlineText(size: Self.headlineSize(headline, width: UIScreen.main.bounds.width - 48))  // the card's 20pt padding each side, and its border

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
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onZone2Tap() }
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
                .accessibilityHidden(true) // a swipe cue; VoiceOver scrolls on its own
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .foregroundColor(zone2TextColor)
    }
}

/// The feed headline in UIKit: SwiftUI cannot set a line height under the
/// font's own (League Spartan Black is 0.92 em, and negative lineSpacing is
/// ignored), and Anton wanted the lines closer (2026-10-04). Tracking -0.05 em.
struct TightHeadline: UIViewRepresentable {
    let text: String
    let size: CGFloat
    static let lineHeight: CGFloat = 0.85

    static func attributes(font: UIFont, size: CGFloat) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight * size
        p.maximumLineHeight = lineHeight * size
        p.lineBreakMode = .byWordWrapping
        return [.font: font, .kern: -0.05 * size, .paragraphStyle: p,
                .foregroundColor: UIColor(Color.warmWhite)]
    }

    /// The squeezed line takes its height off the top, so the first row's
    /// ascenders stuck out above the label and were cut (the top of "bitter
    /// blow", 2026-10-04). The label draws that much lower and is that much
    /// taller.
    final class Label: UILabel {
        var topRoom: CGFloat = 0
        override func drawText(in rect: CGRect) {
            // Moved down, not shrunk: a shorter rect dropped the third row.
            super.drawText(in: rect.offsetBy(dx: 0, dy: topRoom))
        }
        override func sizeThatFits(_ size: CGSize) -> CGSize {
            let s = super.sizeThatFits(size)
            return CGSize(width: s.width, height: s.height + topRoom)
        }
    }

    func makeUIView(context: Context) -> Label {
        let l = Label()
        l.numberOfLines = 3
        l.lineBreakMode = .byTruncatingTail
        l.clipsToBounds = false
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return l
    }

    func updateUIView(_ l: Label, context: Context) {
        let font = UIFont(name: "LeagueSpartan-Black", size: size) ?? .systemFont(ofSize: size, weight: .black)
        l.topRoom = max(0, font.lineHeight - Self.lineHeight * size) + 2
        l.attributedText = NSAttributedString(string: text, attributes: Self.attributes(font: font, size: size))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: Label, context: Context) -> CGSize? {
        let w = proposal.width ?? UIScreen.main.bounds.width
        return CGSize(width: w, height: uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height)
    }
}
