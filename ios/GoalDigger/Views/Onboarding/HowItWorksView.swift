import SwiftUI

/// Onboarding step 7 — three scenario cards explaining when and how the app
/// shows up in real life. Written as moments, not features: "Sunday morning",
/// "Match day", "Saturday at the pub". Personalised with `hisName` so the
/// copy reads like advice from a friend, not a marketing page.
///
/// No fetch. Pure static copy. Comes right after MeetTeamView (which gave
/// her the team facts) and right before TierSelectionView (which chooses
/// the frequency that controls these moments).
struct HowItWorksView: View {
    @Environment(AppState.self) var appState
    let onContinue: () -> Void

    private struct Scenario: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    /// Scenarios use [his name] placeholders rather than inline string
    /// interpolation so empty names fall back to "your partner" via
    /// AppState.personalise (see AppState.swift:100). Same source of truth
    /// as the rest of the app's name-replacement.
    private var scenarios: [Scenario] {
        [
            .init(
                icon: "sun.max.fill",
                title: appState.personalise("Sunday morning, before [his name's] Sunday League"),
                body: "A 30-second brief so you've got something to ask him about over coffee."
            ),
            .init(
                icon: "soccerball.inverse",
                title: "Match day",
                body: appState.personalise("A heads-up before kickoff and a summary when it's done, so you know what to react to when [his name] texts.")
            ),
            .init(
                icon: "sparkles",
                title: "Saturday at the pub",
                body: "One fact you can drop into conversation. We'll send it Saturday lunchtime."
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How this fits\ninto your week.")
                            .font(.onboardingTitle)
                            .foregroundColor(.textOnDark)
                        Text("Three moments where the app earns its keep. We tune the frequency on the next screen.")
                            .font(.onboardingBody)
                            .foregroundColor(.textOnDark.opacity(0.8))
                    }
                    .padding(.top, 24)

                    VStack(spacing: Layout.cardSpacing) {
                        ForEach(scenarios) { scenario in
                            scenarioCard(scenario: scenario)
                        }
                    }
                }
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 24)
            }

            Button("Sounds useful") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func scenarioCard(scenario: Scenario) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.hotRose.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: scenario.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.hotRose)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                    .fixedSize(horizontal: false, vertical: true)
                Text(scenario.body)
                    .font(.jakarta(15, weight: .regular))
                    .foregroundColor(.textSecondaryOnCard)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
