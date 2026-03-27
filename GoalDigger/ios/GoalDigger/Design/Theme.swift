import SwiftUI

/// Goal Digger design system — colors, fonts, spacing, and card styles.
/// Full implementation in task I3. This is the structural placeholder.
enum Theme {

    // MARK: - Colors

    static let appBackground = Color(hex: "FAF8F5")
    static let cardBackground = Color.white
    static let feedDivider = Color(hex: "F0ECE6")
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "8A8480")
    static let textTertiary = Color(hex: "B8B2AA")
    static let accentWarm = Color(hex: "D4956A")
    static let accentSoft = Color(hex: "E8CEB8")
    static let accentGreen = Color(hex: "7DB07E")
    static let cardShadowColor = Color.black.opacity(0.04)
    static let shimmer = Color(hex: "F5F0EA")

    // MARK: - Typography (all SF Rounded)

    static let onboardingTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    static let onboardingBody: Font = .system(.body, design: .rounded)
    static let feedHeadline: Font = .system(.body, design: .rounded, weight: .semibold)
    static let feedTimestamp: Font = .system(.caption, design: .rounded, weight: .medium)
    static let feedBadge: Font = .system(.caption2, design: .rounded, weight: .bold)
    static let detailTitle: Font = .system(.title2, design: .rounded, weight: .bold)
    static let detailBody: Font = .system(.body, design: .rounded)
    static let talkingPointText: Font = .system(.callout, design: .rounded, weight: .medium)
    static let settingsItem: Font = .system(.body, design: .rounded)

    // MARK: - Spacing

    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .shadow(
                color: Theme.cardShadowColor,
                radius: Theme.cardShadowRadius,
                y: Theme.cardShadowY
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
