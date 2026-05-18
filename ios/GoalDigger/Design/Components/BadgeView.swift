import SwiftUI

struct BadgeView: View {
    let type: ContentItem.ContentType
    var customLabel: String? = nil

    var body: some View {
        Text(label)
            .font(.feedBadge)
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(textColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(backgroundColor)
            .cornerRadius(Layout.badgeCornerRadius)
    }

    private var label: String {
        if let custom = customLabel { return custom }
        switch type {
        case .news: return "NEWS"
        case .matchday: return "MATCH DAY"
        case .sundayBrief: return "SUNDAY BRIEF"
        case .startingXi: return "STARTING XI"
        }
    }

    private var textColor: Color {
        switch type {
        case .news: return .badgeNewsText
        case .matchday: return .badgeMatchdayText
        // Sunday Brief + Starting XI reuse the news colourway (warm white
        // on hot rose). No new colour pair needed; the label change
        // carries the signal.
        case .sundayBrief: return .badgeNewsText
        case .startingXi: return .badgeNewsText
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .news: return .badgeNews
        case .matchday: return .badgeMatchday
        case .sundayBrief: return .badgeNews
        case .startingXi: return .badgeNews
        }
    }
}
