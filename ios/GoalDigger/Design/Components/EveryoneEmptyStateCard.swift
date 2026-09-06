import SwiftUI

/// Empty state shown in the "Everyone's Talking About" feed when no cross-team stories exist.
/// Full height (88% screen) to match immersive card dimensions.
struct EveryoneEmptyStateCard: View {
    let cardHeight: CGFloat
    let teamName: String
    let onBackToTeam: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "soccerball")
                .font(.system(size: 32))
                .foregroundColor(.hotRose)

            Text("Nothing huge in football today.")
                .font(.jakarta(17, weight: .semiBold))
                .foregroundColor(.charcoal)

            Text("Enjoy the quiet. We'll flag it the moment \(teamName) do something.")
                .font(.jakarta(12, weight: .regular))
                .foregroundColor(.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onBackToTeam) {
                Text("Back to \(teamName)")
                    .font(.jakarta(17, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.hotRose)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .background(Color.softBlush)
    }
}
