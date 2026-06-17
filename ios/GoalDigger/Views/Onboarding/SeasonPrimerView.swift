import SwiftUI

/// One-time-per-install primer. NOTE (ONB-8): new users no longer reach this —
/// completeOnboarding() pre-sets hasSeenSeasonPrimer=true, so RootView's
/// !hasSeenSeasonPrimer branch only fires after a Delete-My-Data re-onboard.
/// Reads from `team_season_state` (populated daily by the gd-season-state
/// cloud routine) and renders the redesigned **one-beat** primer:
///
///   - `state_line` — a 2-5 word personalised headline naming the team's
///                    emotional state right now ("Arsenal are flying").
///   - `feeling_line` — one sentence on how HE will feel/act this week.
///   - A single full-width "Continue" CTA that lands on the feed.
///
/// The original primer rendered a stat summary + key fact + 3 quotables
/// + 2 CTAs. Smoke testing showed it was overwhelming for brand-new users.
/// The redesign collapses to two strings and one action — see
/// `glimmering-foraging-jellyfish.md` plan for the design rationale.
///
/// Failure handling stays defensive: any fetch error, empty response, or
/// missing state_line marks `hasSeenSeasonPrimer = true` and falls through
/// to the feed. We never block a new user behind a slow or broken backend.
struct SeasonPrimerView: View {
    @Environment(AppState.self) var appState
    let onTeachMore: () -> Void  // kept on the API for an optional tertiary link in future iterations
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
                } else if let state, let stateLine = state.stateLine, let feelingLine = state.feelingLine {
                    primerContent(stateLine: stateLine, feelingLine: feelingLine)
                } else {
                    // Fetch failed, returned nothing, or returned a legacy row
                    // (no state_line). Either way, skip to feed — better than
                    // showing the old overwhelming layout to a brand-new user.
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
    private func primerContent(stateLine: String, feelingLine: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lots of top breathing room. The card should feel quiet.
            Spacer()
                .frame(height: 80)

            // The punchy headline. 2-5 words from the routine.
            Text(appState.personalise(stateLine))
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Layout.screenPadding)

            // Generous gap between title and body.
            Spacer()
                .frame(height: 24)

            // One sentence (or two short ones) of emotional translation.
            // Wrap in GlossaryText so any jargon ("run-in", "clean sheet")
            // is tappable — defensive in case the LLM uses one despite the
            // prompt asking it not to.
            GlossaryText(raw: appState.personalise(feelingLine))
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.85))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Layout.screenPadding)

            Spacer()

            // Two CTAs — restored on request after first sim test.
            // Primary nudges her to learn more about the team (the higher-
            // intent path); secondary text link skips straight to the feed.
            VStack(spacing: 10) {
                Button("Teach me more about the team", action: onTeachMore)
                    .buttonStyle(PrimaryButtonStyle())

                Button("Take me to the news", action: onSkipToFeed)
                    .font(.feedHeadline)
                    .foregroundColor(.hotRose)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 32)
        }
    }
}
