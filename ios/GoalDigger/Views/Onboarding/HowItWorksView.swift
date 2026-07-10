import SwiftUI

/// Onboarding explainer — three plain-English cards on HOW THE APP WORKS:
/// we watch his teams, we always hand her something to say, and anything she
/// doesn't understand is tappable. Replaced the old "how this fits into your
/// week" weekly-rhythm framing (which assumed he plays Sunday League).
/// Personalised with `hisName` via AppState.personalise.
///
/// No fetch. Pure static copy.
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
                icon: "dot.radiowaves.left.and.right",
                title: "We watch \(appState.pPossessive) teams for you",
                body: appState.personalise("Every match and every story about [his name's] teams, turned into plain English. No jargon, no homework.")
            ),
            .init(
                icon: "bubble.left.and.bubble.right.fill",
                title: "You always have something to say",
                body: "A heads-up before kickoff, the score while it's live, and the line that starts the chat once it's done."
            ),
            .init(
                icon: "hand.tap.fill",
                title: "Tap anything you don't get",
                body: "See a word underlined, like clean sheet or World Championship? Tap it for a quick, human explanation."
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Here's how\nit works.")
                            .font(.onboardingTitle)
                            .foregroundColor(.textOnDark)
                        Text("We keep you in the loop on \(appState.pPossessive) football, in plain English, so you can jump in whenever.")
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
