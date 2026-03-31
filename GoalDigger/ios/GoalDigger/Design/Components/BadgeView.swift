import SwiftUI

struct BadgeView: View {
    let text: String
    let backgroundColor: Color
    let textColor: Color

    var body: some View {
        Text(text)
            .font(Theme.feedBadge)
            .foregroundStyle(textColor)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
