import SwiftUI

/// Empty state shown in the "Everyone's Talking About" feed when no cross-team stories exist.
/// Full height (88% screen) to match immersive card dimensions.
struct EveryoneEmptyStateCard: View {
    let cardHeight: CGFloat
    /// nil when nothing followed has a feed (a country-only device while
    /// country following is off): no team to name, no button to go back to.
    let teamName: String?
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

            Text(teamName.map { "Enjoy the quiet. We'll flag it the moment \($0) do something." }
                 ?? "Enjoy the quiet. We'll flag it the moment something happens.")
                .font(.jakarta(12, weight: .regular))
                .foregroundColor(.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let teamName {
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
            }

            Spacer()
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .background(Color.softBlush)
    }
}
