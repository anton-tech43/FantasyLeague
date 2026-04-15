import SwiftUI

struct TeamPageMoodBanner: View {
    let mood: MoodCard
    @Environment(AppState.self) var appState

    private var backgroundTint: Color {
        switch mood.state {
        case .good: return Color.hotRose.opacity(0.12)
        case .bad: return Color.red.opacity(0.08)
        case .neutral: return Color.clear
        }
    }

    var body: some View {
        ZStack {
            Color.deepMauve
            backgroundTint

            Text(appState.personalise(mood.text))
                .font(.jakarta(15, weight: .medium))
                .foregroundColor(.warmWhite)
                .multilineTextAlignment(.center)
                .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.15)
        .cornerRadius(16)
    }
}
