import SwiftUI

struct TeamPageThisWeek: View {
    let card: ThisWeekCard
    @Environment(AppState.self) var appState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hotRose

            VStack(alignment: .leading, spacing: 10) {
                // THIS WEEK pill
                Text("THIS WEEK")
                    .font(.jakarta(11, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.15))
                    .clipShape(Capsule())

                // Body text
                Text(appState.personalise(card.text))
                    .font(.jakarta(17, weight: .regular))
                    .foregroundColor(.warmWhite)

                // Talking point
                Text(appState.personalise(card.talkingPoint))
                    .font(.jakarta(15, weight: .mediumItalic))
                    .foregroundColor(.warmWhite)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .cornerRadius(16)
    }
}
