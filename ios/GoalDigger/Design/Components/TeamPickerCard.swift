import SwiftUI

struct TeamPickerCard: View {
    let team: Team
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(team.displayName)
                    .font(.feedHeadline)
                    .foregroundColor(.textPrimaryOnCard)
                Spacer()
                if isSelected {
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
                    .stroke(isSelected ? Color.hotRose : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
        }
    }
}
