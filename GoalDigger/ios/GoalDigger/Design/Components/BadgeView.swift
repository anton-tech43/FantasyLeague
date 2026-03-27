import SwiftUI

/// Badge component showing content type (news / matchday).
/// Full implementation in task I12.
struct BadgeView: View {
    let type: ContentItem.ContentType

    private var label: String {
        switch type {
        case .news: return "NEWS"
        case .matchday: return "MATCHDAY"
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .news: return Theme.accentSoft
        case .matchday: return Theme.accentGreen
        }
    }

    var body: some View {
        Text(label)
            .font(Theme.feedBadge)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}
