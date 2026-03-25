import SwiftUI

/// Badge that displays content type: NEWS or MATCH DAY.
struct BadgeView: View {
    let type: ContentItem.ContentType

    var body: some View {
        Text(label)
            .font(.feedBadge)
            .textCase(.uppercase)
            .foregroundColor(foregroundColor)
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

    private var foregroundColor: Color {
        switch type {
        case .news: return .accentWarm
        case .matchday: return .accentGreen
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .news: return .accentSoft
        case .matchday: return .accentGreen.opacity(0.2)
        }
    }
}

#Preview {
    HStack {
        BadgeView(type: .news)
        BadgeView(type: .matchday)
    }
    .padding()
}
