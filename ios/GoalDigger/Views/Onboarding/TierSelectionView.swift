import SwiftUI

struct TierSelectionView: View {
    @Environment(AppState.self) var appState
    @State private var selected: Int = 2
    let onContinue: () -> Void

    private let tiers: [(number: Int, label: String, description: String)] = [
        (1, "Just enough to get by", "Match day heads-up and one key talking point."),
        (2, "Came to impress", "Regular news and talking points through the week."),
        (3, "The one he brags about", "Everything including deep news, stats context and transfer rumours.")
    ]

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
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
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

            Button("Continue") {
                appState.selectedTier = selected
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
    }
}
