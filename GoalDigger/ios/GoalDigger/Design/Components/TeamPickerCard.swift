import SwiftUI

// TODO: Implement in I12
struct TeamPickerCard: View {
    let team: Team
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(team.displayName)
                .font(Theme.feedHeadline)
        }
        .cardStyle()
    }
}
