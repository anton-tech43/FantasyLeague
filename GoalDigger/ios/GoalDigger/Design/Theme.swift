import SwiftUI

// MARK: - Goal Digger Design System
// "Soft intel" — warm, editorial, intimate. Vogue meets WhatsApp.
// Relationship-coded, not sports-coded.

enum Theme {
    // MARK: - Colors (Warm cream + dusty rose + terracotta)

    static let appBackgroundTop = Color(hex: "FAF5EF")     // warm cream top
    static let appBackgroundBottom = Color(hex: "F5EDE4")   // warmer cream bottom
    static let appBackground = Color(hex: "FAF5EF")         // fallback
    static let cardBackground = Color(hex: "FFFBF7")        // barely-warm white
    static let cardBackgroundAlt = Color(hex: "F7F0E8")     // warm tinted card (quiet states)
    static let cardBorder = Color(hex: "D4A989").opacity(0.25) // soft terracotta border
    static let feedDivider = Color(hex: "EDE5DA")
    static let textPrimary = Color(hex: "2C2420")           // warm near-black
    static let textSecondary = Color(hex: "8A7D74")         // warm brown-gray
    static let textTertiary = Color(hex: "B5A99E")          // light warm gray
    static let accentWarm = Color(hex: "C4785A")            // dusty terracotta — primary
    static let accentSoft = Color(hex: "EACFC0")            // dusty rose — backgrounds
    static let accentPeach = Color(hex: "E8B796")           // warm peach — secondary
    static let accentGreen = Color(hex: "8EAE7E")           // muted sage — matchday
    static let cardShadow = Color(hex: "C4785A").opacity(0.06)
    static let shimmer = Color(hex: "F0E8DF")

    // Mood card tints — subtle warmth per emotional context
    static let moodExciting = Color(hex: "FFF5EC")
    static let moodBadNews = Color(hex: "F5F0ED")
    static let moodDrama = Color(hex: "F8F0F5")
    static let moodFunny = Color(hex: "FDFAEC")

    /// Gradient background for screens
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [appBackgroundTop, appBackgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography (serif headlines + rounded sans body)
    // Serif for editorial warmth on headlines, rounded sans for readability

    static let onboardingTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let onboardingBody = Font.system(.body, design: .rounded, weight: .regular)
    static let feedHeadline = Font.system(.body, design: .serif, weight: .semibold)
    static let feedTimestamp = Font.system(.caption, design: .rounded, weight: .medium)
    static let feedBadge = Font.system(.caption2, design: .rounded, weight: .bold)
    static let detailTitle = Font.system(.title2, design: .serif, weight: .bold)
    static let detailBody = Font.system(.body, design: .rounded, weight: .regular)
    static let detailBodyItalic = Font.system(.callout, design: .serif, weight: .regular).italic()
    static let talkingPointText = Font.system(.callout, design: .rounded, weight: .medium)
    static let settingsItem = Font.system(.body, design: .rounded, weight: .regular)
    static let conversationStarter = Font.system(.callout, design: .serif, weight: .medium).italic()

    // MARK: - Spacing

    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 14
    static let cardCornerRadius: CGFloat = 18
    static let cardShadowRadius: CGFloat = 10
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    var moodTint: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(moodTint ?? Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: Theme.cardShadow,
                radius: Theme.cardShadowRadius,
                x: 0,
                y: Theme.cardShadowY
            )
    }
}

extension View {
    func cardStyle(moodTint: Color? = nil) -> some View {
        modifier(CardStyle(moodTint: moodTint))
    }
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
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
