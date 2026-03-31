import SwiftUI

struct TeamPickerCard: View {
    let team: Team
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(team.displayName)
                    .font(Theme.feedHeadline)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accentWarm)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(Theme.cardPadding)
            .frame(height: 80)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .stroke(
                        isSelected ? Theme.accentWarm : .clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: Theme.cardShadow,
                radius: Theme.cardShadowRadius,
                x: 0,
                y: Theme.cardShadowY
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
