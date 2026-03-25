import SwiftUI

// MARK: - Color Palette

extension Color {
    // Backgrounds
    static let appBackground = Color(hex: "#FAF8F5")
    static let cardBackground = Color.white
    static let feedDivider = Color(hex: "#F0ECE6")

    // Text
    static let textPrimary = Color(hex: "#1A1A1A")
    static let textSecondary = Color(hex: "#8A8480")
    static let textTertiary = Color(hex: "#B8B2AA")

    // Accents
    static let accentWarm = Color(hex: "#D4956A")
    static let accentSoft = Color(hex: "#E8CEB8")
    static let accentGreen = Color(hex: "#7DB07E")

    // Utility
    static let cardShadow = Color.black.opacity(0.04)
    static let shimmer = Color(hex: "#F5F0EA")
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography (SF Rounded throughout)

extension Font {
    static let onboardingTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let onboardingBody = Font.system(.body, design: .rounded, weight: .regular)
    static let feedHeadline = Font.system(.body, design: .rounded, weight: .semibold)
    static let feedTimestamp = Font.system(.caption, design: .rounded, weight: .medium)
    static let feedBadge = Font.system(.caption2, design: .rounded, weight: .bold)
    static let detailTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let detailBody = Font.system(.body, design: .rounded, weight: .regular)
    static let talkingPointText = Font.system(.callout, design: .rounded, weight: .medium)
    static let settingsItem = Font.system(.body, design: .rounded, weight: .regular)
}

// MARK: - Spacing & Layout Constants

struct Layout {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Layout.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .shadow(color: Color.cardShadow, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
