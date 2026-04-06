import SwiftUI

// MARK: - Color Palette (Rose and Dusk)

extension Color {
    // Core palette
    static let hotRose = Color(hex: "#E8397D")
    static let deepMauve = Color(hex: "#2D1B2E")
    static let softBlush = Color(hex: "#FAF0F4")
    static let warmWhite = Color(hex: "#F5F0F0")
    static let gold = Color(hex: "#E8C547")

    // Semantic aliases
    static let appBackground = Color.deepMauve
    static let cardBackground = Color.softBlush
    static let textOnDark = Color.warmWhite
    static let accentPrimary = Color.hotRose
    static let tierGold = Color.gold

    // Derived text colors
    static let textPrimaryOnCard = Color(hex: "#2D1B2E")
    static let textSecondaryOnCard = Color(hex: "#8A7080")
    static let textTertiary = Color(hex: "#B8A0AA")

    // Derived utility colors
    static let feedDivider = Color(hex: "#3D2B3E")
    static let cardShadowColor = Color.black.opacity(0.12)
    static let shimmer = Color(hex: "#3D2B3E")

    // Accent colors (from BUILD_PLAN warm palette, adapted to Rose and Dusk)
    static let accentWarm = Color(hex: "#D4725C")          // Warm terracotta — talking point bars, share button
    static let accentSoft = Color(hex: "#F0DDD5")          // Soft warm — talking point card backgrounds
    static let accentGreen = Color(hex: "#3DA66C")         // Muted green — matchday badges

    // Badge colors
    static let badgeMatchday = Color.accentGreen.opacity(0.2)
    static let badgeMatchdayText = Color.accentGreen
    static let badgeNews = Color.accentSoft
    static let badgeNewsText = Color.accentWarm

    // Post-match card tints
    static let winTint = Color.green.opacity(0.08)
    static let winBar = Color.green.opacity(0.5)
    static let loseTint = Color.red.opacity(0.06)
    static let loseBar = Color.red.opacity(0.4)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

// MARK: - Typography (SF Rounded)

extension Font {
    // Onboarding
    static let onboardingTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let onboardingBody = Font.system(.body, design: .rounded, weight: .regular)

    // Feed
    static let feedHeadline = Font.system(.body, design: .rounded, weight: .semibold)
    static let feedTimestamp = Font.system(.caption, design: .rounded, weight: .medium)
    static let feedBadge = Font.system(.caption2, design: .rounded, weight: .bold)

    // Detail view
    static let detailTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let detailBody = Font.system(.body, design: .rounded, weight: .regular)
    static let talkingPointText = Font.system(.callout, design: .rounded, weight: .medium)

    // Section headers
    static let sectionHeader = Font.system(.caption, design: .rounded, weight: .bold)

    // Settings
    static let settingsItem = Font.system(.body, design: .rounded, weight: .regular)
}

// MARK: - Layout Constants

struct Layout {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8
    static let buttonHeight: CGFloat = 50
    static let buttonCornerRadius: CGFloat = 16
}

// MARK: - Reusable Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Layout.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Shared Utilities

extension Date {
    var relativeTimestamp: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 3600 {
            return "\(max(1, Int(interval / 60)))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else {
            return "\(Int(interval / 86400)) days ago"
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.buttonHeight)
            .background(isEnabled ? Color.hotRose : Color.hotRose.opacity(0.4))
            .cornerRadius(Layout.buttonCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
