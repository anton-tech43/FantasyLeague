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
        isGoldVariant ? .black : .warmWhite
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

                // Headline
                Text(headline)
                    .font(.immersiveHeadline)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                    .foregroundColor(.warmWhite)

                // Context/analogy line
                if let context = contextLine, !context.isEmpty {
                    Text(context)
                        .font(.immersiveContext)
                        .foregroundColor(.warmWhite)
                        .padding(.top, 12)
                        .lineLimit(3)
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
            // 3px inset rose border (top, left, right, bottom)
            Rectangle()
                .stroke(Color.hotRose, lineWidth: 3)
                .padding(1.5)
        )
    }

    // MARK: - Zone 2 (35%)

    private var zone2: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text(zone2Label)
                    .font(.jakarta(17, weight: .bold))
                Text(talkingPoint)
                    .font(.jakarta(17, weight: .mediumItalic))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Scroll indicator
            VStack(spacing: 2) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                Text("scroll")
                    .font(.jakarta(12, weight: .medium))
            }
            .foregroundColor(zone2TextColor.opacity(0.6))
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(zone2Background)
        .foregroundColor(zone2TextColor)
    }
}
