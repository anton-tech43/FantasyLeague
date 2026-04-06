import SwiftUI

struct TeamSelectionView: View {
    @Environment(AppState.self) var appState
    @State private var selected: Team?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Who does \(appState.hisName.isEmpty ? "he" : appState.hisName) support?")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Text("Pick one and we'll keep you in the loop.")
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .padding(.horizontal, Layout.screenPadding)

            VStack(spacing: Layout.cardSpacing) {
                ForEach(Team.allCases) { team in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = team
                        }
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    } label: {
                        HStack {
                            Text(team.displayName)
                                .font(.feedHeadline)
                                .foregroundColor(.textPrimaryOnCard)
                            Spacer()
                            if selected == team {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.hotRose)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondaryOnCard)
                            }
                        }
                        .padding(Layout.cardPadding)
                        .frame(height: 80)
                        .background(Color.cardBackground)
                        .cornerRadius(Layout.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                                .stroke(selected == team ? Color.hotRose : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(selected == team ? 1.02 : 1.0)
                        .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)

            Spacer()

            if let team = selected {
                Button("Continue") {
                    appState.selectedTeam = team
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.screenPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 40)
        }
        .animation(.easeOut(duration: 0.2), value: selected)
    }
}
