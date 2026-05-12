import SwiftUI

/// Top-of-feed card shown when his team has a live PL match in progress.
/// Polled into existence every 60s by FeedView. Visually distinct from the
/// normal feed cards: hot-rose live indicator that pulses, trigger label
/// (HALF TIME / 75 MIN / etc), then the brief headline + body. No vertical
/// rose accent bar — this is the loudest card on the feed and shouldn't be
/// camouflaged among the others. T2+ only; gating handled in FeedView.
struct LiveMatchCard: View {
    let brief: LiveMatchBrief

    @State private var pulseOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: pulsing dot + LIVE + trigger label + minute
            HStack(spacing: 8) {
                // Pulsing live indicator. Uses opacity + scale animation
                // so it reads as "active" without being annoying.
                Circle()
                    .fill(Color.hotRose)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulseOn ? 1.4 : 1.0)
                    .opacity(pulseOn ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulseOn
                    )

                Text("LIVE")
                    .font(.jakarta(11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.hotRose)

                Text("·")
                    .font(.jakarta(11, weight: .bold))
                    .foregroundColor(.warmWhite.opacity(0.5))

                Text(brief.displayTriggerLabel)
                    .font(.jakarta(11, weight: .semiBold))
                    .tracking(1)
                    .foregroundColor(.warmWhite.opacity(0.8))

                if let minute = brief.minute, brief.triggerLabel != "HT" {
                    Text("·")
                        .font(.jakarta(11, weight: .bold))
                        .foregroundColor(.warmWhite.opacity(0.5))
                    Text("\(minute)'")
                        .font(.jakarta(11, weight: .semiBold))
                        .foregroundColor(.warmWhite.opacity(0.8))
                }

                Spacer()
            }

            // Headline — the hook, bold
            Text(brief.headline)
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.warmWhite)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Body — the context, regular
            Text(brief.body)
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            // Subtle hot-rose tint over deep mauve. Reads as "alive" without
            // being so loud it overpowers the rest of the feed.
            ZStack {
                Color.deepMauve
                Color.hotRose.opacity(0.08)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.5), lineWidth: 1.5)
        )
        .cornerRadius(Layout.cardCornerRadius)
        .onAppear {
            // Start the pulse on first appear. SwiftUI restores animation
            // state when the view returns from background.
            pulseOn = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live match update for your team: \(brief.headline). \(brief.body)")
    }
}
