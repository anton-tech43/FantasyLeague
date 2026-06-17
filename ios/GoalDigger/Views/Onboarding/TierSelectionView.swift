import SwiftUI

struct TierSelectionView: View {
    @Environment(AppState.self) var appState
    @State private var selected: Int = 2
    let onContinue: () -> Void

    private var tiers: [(number: Int, icon: String, label: String, description: String)] {
        [
            (1, "cup.and.saucer", "Just enough to get by", "Just the essentials. No overload."),
            (2, "bolt.fill", "Came to impress", "Enough to hold your own in any conversation."),
            (3, "crown.fill", "The one \(appState.pSubject) \(appState.usesHeVoice ? "brags" : "brag") about",
             "She knows things \(appState.pSubject) \(appState.usesHeVoice ? "hasn't" : "haven't") even googled yet.")
        ]
    }

    private var buttonText: String {
        switch selected {
        case 1: return "Sounds good"
        case 2: return "Let's do this"
        case 3: return "Say less"
        default: return "Let's do this"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How far do you\nwant to take this?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            VStack(spacing: Layout.cardSpacing) {
                ForEach(tiers, id: \.number) { tier in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = tier.number
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: tier.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(tier.number == 3 ? .tierGold : .hotRose)
                                    .frame(width: 24)

                                Text(tier.label)
                                    .font(.feedHeadline)
                                    .foregroundColor(.textPrimaryOnCard)

                                Spacer()

                                if selected == tier.number {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(tier.number == 3 ? .tierGold : .hotRose)
                                }
                            }
                            Text(tier.description)
                                .font(.onboardingBody)
                                .foregroundColor(.textSecondaryOnCard)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 24 + 8) // align with text after icon
                        }
                        .padding(Layout.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(Layout.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                                .stroke(
                                    selected == tier.number
                                        ? (tier.number == 3 ? Color.tierGold : Color.hotRose)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)

            Spacer()

            Button(buttonText) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                appState.selectedTier = selected
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
    }
}
