import SwiftUI

struct BadgeView: View {
    let type: ContentItem.ContentType

    var body: some View {
        Text(label)
            .font(.feedBadge)
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(textColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(backgroundColor)
            .cornerRadius(8)
    }

    private var label: String {
        switch type {
        case .news: return "NEWS"
        case .matchday: return "MATCH DAY"
        }
    }

    private var textColor: Color {
        switch type {
        case .news: return .badgeNewsText
        case .matchday: return .badgeMatchdayText
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .news: return .badgeNews
        case .matchday: return .badgeMatchday
        }
    }
}
