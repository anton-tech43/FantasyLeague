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
                    Text(minute <= 90 ? "\(minute)' / 90" : "\(minute)'")
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

            // Scorers — who scored and when, chronological. Sits right under the
            // scoreline so the live box reads score → goals → context.
            if let scorers = brief.scorers, !scorers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(scorers) { scorer in
                        HStack(spacing: 8) {
                            Text(scorer.minute.isEmpty ? "·" : scorer.minute)
                                .font(.jakarta(12, weight: .bold))
                                .foregroundColor(.hotRose)
                                .frame(width: 40, alignment: .leading)
                            if let photoURL = scorer.photoURL {
                                AsyncImage(url: photoURL) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Color.clear
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                            }
                            Text(scorer.player + (scorer.penalty == true ? " (pen)" : ""))
                                .font(.jakarta(13, weight: .regular))
                                .foregroundColor(.warmWhite)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(scorer.team.uppercased())
                                .font(.jakarta(10, weight: .semiBold))
                                .tracking(0.5)
                                .foregroundColor(.warmWhite.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.top, 2)
            }

            // Body — the context, regular
            Text(brief.body)
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Group standings — the live box doubles as group context during
            // the match. Compact: position, team, played, points.
            if let standings = brief.standings, !standings.entries.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(standings.competitionLabel.uppercased())
                        .font(.jakarta(11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.hotRose)
                        .padding(.top, 6)
                    ForEach(standings.entries) { row in
                        HStack(spacing: 10) {
                            Text("\(row.rank)")
                                .font(.jakarta(12, weight: .semiBold))
                                .foregroundColor(.warmWhite.opacity(0.5))
                                .frame(width: 12, alignment: .leading)
                            Text(row.team)
                                .font(.jakarta(13, weight: .regular))
                                .foregroundColor(.warmWhite)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(row.played)")
                                .font(.jakarta(12, weight: .regular))
                                .foregroundColor(.warmWhite.opacity(0.55))
                            Text("\(row.points)")
                                .font(.jakarta(13, weight: .bold))
                                .foregroundColor(.warmWhite)
                                .frame(width: 22, alignment: .trailing)
                        }
                    }
                }
            }
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
