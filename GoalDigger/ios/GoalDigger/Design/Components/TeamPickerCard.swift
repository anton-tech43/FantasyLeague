import SwiftUI

/// Tappable team card used in onboarding and settings team change.
/// Horizontal rectangle, 80pt tall, with team name and chevron.
struct TeamPickerCard: View {
    let team: Team
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(team.displayName)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.textTertiary)
            }
            .padding(Layout.cardPadding)
            .frame(height: 80)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .shadow(color: Color.cardShadow, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(isSelected ? Color.accentWarm : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: Layout.cardSpacing) {
        TeamPickerCard(team: .arsenal, isSelected: true, onTap: {})
        TeamPickerCard(team: .manUtd, isSelected: false, onTap: {})
        TeamPickerCard(team: .westHam, isSelected: false, onTap: {})
    }
    .padding()
    .background(Color.appBackground)
}
