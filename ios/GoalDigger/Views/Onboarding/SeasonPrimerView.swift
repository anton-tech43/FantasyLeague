import SwiftUI

/// The one-time-per-install screen shown right after onboarding completes.
/// Reads from `team_season_state` (populated daily by the gd-season-state
/// cloud routine) and renders:
///   - A phase-aware headline ("It's the run-in.", "Pre-season is on.", ...)
///   - The 2-sentence summary
///   - One notable key fact
///   - Three short text-message-style welcome lines, each with copy + share
///   - Two CTAs: "Teach me more about the team" → His Team tab,
///                "Take me to the news" → Feed tab
///
/// Failure handling is defensive: any fetch error, empty response, or
/// missing-team state marks `hasSeenSeasonPrimer = true` and falls through
/// to the feed. We never block a brand-new user behind a slow or broken
/// backend. The data still surfaces in the daily routine, and we can build a
/// re-entry surface (e.g., a "Season state" entry on His Team) later.
struct SeasonPrimerView: View {
    @Environment(AppState.self) var appState
    let onTeachMore: () -> Void
    let onSkipToFeed: () -> Void

    @State private var state: TeamSeasonState?
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.hotRose)
                        .scaleEffect(1.2)
                    Spacer()
                } else if let state {
                    primerContent(state)
                } else {
                    // Fetch failed or returned nothing. Skip to feed.
                    // Use Color.clear + onAppear so the skip happens after the
                    // view has actually rendered — avoids a SwiftUI state-
                    // update-during-body warning.
                    Color.clear
                        .onAppear { onSkipToFeed() }
                }
            }
        }
        .task {
            await loadState()
        }
    }

    // MARK: - Loading

    @MainActor
    private func loadState() async {
        guard let teamId = appState.selectedTeam?.rawValue else {
            // No team selected (shouldn't happen — picker is mandatory in
            // onboarding). Skip the primer.
            isLoading = false
            return
        }
        do {
            state = try await APIClient.shared.fetchTeamSeasonState(teamId: teamId)
        } catch {
            #if DEBUG
            print("⚠️ SeasonPrimer fetch failed: \(error)")
            #endif
            state = nil
        }
        isLoading = false
    }

    // MARK: - Content

    @ViewBuilder
    private func primerContent(_ s: TeamSeasonState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                // Phase headline + summary
                VStack(alignment: .leading, spacing: 12) {
                    Text(phaseHeadline(s.phase))
                        .font(.onboardingTitle)
                        .foregroundColor(.textOnDark)
                        .multilineTextAlignment(.leading)
                    Text(s.summary)
                        .font(.onboardingBody)
                        .foregroundColor(.textOnDark.opacity(0.85))
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }

                // Key fact pill
                if !s.keyFact.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundColor(.hotRose)
                            .padding(.top, 2)
                        Text(s.keyFact)
                            .font(.jakarta(15, weight: .medium))
                            .foregroundColor(.textOnDark)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hotRose.opacity(0.08))
                    .cornerRadius(Layout.cardCornerRadius)
                }

                // Welcome lines section
                if !s.welcomeLines.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 12))
                            Text("THREE THINGS TO SEND HIM NOW")
                                .font(.sectionHeader)
                                .tracking(1)
                        }
                        .foregroundColor(.textTertiary)

                        ForEach(Array(s.welcomeLines.enumerated()), id: \.offset) { _, line in
                            WelcomeLineRow(text: line)
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            ctaButtons
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 24)
                .padding(.top, 12)
                .background(
                    LinearGradient(
                        colors: [Color.appBackground.opacity(0), Color.appBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .offset(y: -60),
                    alignment: .top
                )
                .background(Color.appBackground)
        }
    }

    @ViewBuilder
    private var ctaButtons: some View {
        VStack(spacing: 10) {
            Button("Teach me more about the team", action: onTeachMore)
                .buttonStyle(PrimaryButtonStyle())

            Button("Take me to the news", action: onSkipToFeed)
                .font(.feedHeadline)
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func phaseHeadline(_ phase: TeamSeasonState.Phase) -> String {
        switch phase {
        case .preSeason:  return "Pre-season is on."
        case .midSeason:  return "Here's where they're at."
        case .runIn:      return "It's the run-in."
        case .offSeason:  return "Quiet patch right now."
        case .postSeason: return "Season's done. Here's the dust."
        }
    }
}

/// One row of the "three things to send him" list. Text + copy + share, all
/// inline. Reuses `CopyButton` from the shared D2 component file.
private struct WelcomeLineRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text)
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.textPrimaryOnCard)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                CopyButton(text: text)
                ShareLink(item: text, preview: SharePreview("From GoalDigger")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.hotRose)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Share line")
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
    }
}
