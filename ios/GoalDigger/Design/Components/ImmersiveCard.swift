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

    private var contextLine: String? {
        if case .everyoneTalking = feedContext {
            return item.displayContext
        }
        guard let raw = item.displayContext, !raw.isEmpty else { return nil }
        let personalised = appState.personalise(raw)
        return personalised.isEmpty ? nil : personalised
    }

    private var talkingPoint: String {
        if case .everyoneTalking = feedContext {
            return item.everyoneTalkingTalkingPoints?.first ?? item.regularTalkingPoints.first ?? ""
        }
        return appState.personalise(item.regularTalkingPoints.first ?? "")
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
                .frame(height: cardHeight * 0.75)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { onZone1Tap() }
            zone2
                .frame(height: cardHeight * 0.25)
                .contentShape(Rectangle())
                .onTapGesture { onZone2Tap() }
        }
        .frame(height: cardHeight)
        .clipped()
    }

    // MARK: - Zone 1 (65%)

    private var zone1: some View {
        ZStack(alignment: .topLeading) {
            Color.deepMauve

            VStack(alignment: .leading, spacing: 0) {
                // Headline — starts lower in zone 1 so it sits centrally on card
                Text(headline)
                    .font(.immersiveHeadline)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                    .foregroundColor(.warmWhite)
                    .padding(.top, cardHeight * 0.22)  // moved down one notch

                // Context/analogy line (the "girl translation") — always show full
                if let context = contextLine, !context.isEmpty {
                    Text(context)
                        .font(.immersiveContext)
                        .foregroundColor(.warmWhite)
                        .padding(.top, 14)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 20)

                // Press hint — pinned near bottom of zone 1
                Text("Press for more info and things to say")
                    .font(.immersiveHint)
                    .foregroundColor(.warmWhite.opacity(0.45))
                    .padding(.bottom, 16)
            }
            .padding(20)
        }
        // 5px rose border on TOP / LEFT / RIGHT only — no border on the bottom
        // edge so the pink zone 2 below has zero visible border.
        .overlay(
            GeometryReader { geo in
                Path { path in
                    let inset: CGFloat = 2.5
                    let w = geo.size.width
                    let h = geo.size.height
                    // Start at bottom-left (open), go up, across top, back down to bottom-right (open)
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

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text(zone2Label)
                        .font(.jakarta(17, weight: .bold))
                    Text("“\(talkingPoint)”")
                        .font(.jakarta(17, weight: .mediumItalic))
                        .lineLimit(3)
                }

                Spacer()

                // Scroll indicator
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
