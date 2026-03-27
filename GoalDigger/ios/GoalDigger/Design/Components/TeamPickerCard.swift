import SwiftUI

/// Card for selecting a team during onboarding.
/// Full implementation in task I12.
struct TeamPickerCard: View {
    let team: Team
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.displayName)
                        .font(Theme.feedHeadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accentWarm)
                        .font(.title3)
                }
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .stroke(isSelected ? Theme.accentWarm : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
