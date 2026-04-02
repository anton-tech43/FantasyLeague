import SwiftUI

// MARK: - Goal Digger Design System
// All colors, typography, and spacing constants.
// Reference: Agent2_Instructions.md Design System section.

enum Theme {
    // MARK: - Colors (Blush & Playful palette)

    static let appBackgroundTop = Color(hex: "FFF5F5")
    static let appBackgroundBottom = Color(hex: "FFF0E8")
    static let appBackground = Color(hex: "FFF5F5") // fallback for non-gradient contexts
    static let cardBackground = Color.white
    static let cardBorder = Color(hex: "E8A0BF").opacity(0.35)
    static let feedDivider = Color(hex: "F5E0E8")
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "8A7F85")
    static let textTertiary = Color(hex: "B8AAAF")
    static let accentWarm = Color(hex: "E8A0BF")   // blush pink — primary accent
    static let accentSoft = Color(hex: "FFD6E0")    // soft pink — backgrounds
    static let accentPeach = Color(hex: "FFCBA4")   // peach — secondary accent
    static let accentGreen = Color(hex: "7EC8A8")   // fresh mint
    static let cardShadow = Color(hex: "E8A0BF").opacity(0.08)
    static let shimmer = Color(hex: "FFE8EE")

    // Mood card tints — subtle background tint per emotional context
    static let moodExciting = Color(hex: "FFF3E8").opacity(0.6)
    static let moodBadNews = Color(hex: "F0EEF5").opacity(0.6)
    static let moodDrama = Color(hex: "F5EEFF").opacity(0.6)
    static let moodFunny = Color(hex: "FEFCE8").opacity(0.6)

    /// Gradient background for screens
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [appBackgroundTop, appBackgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography (all SF Rounded)

    static let onboardingTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let onboardingBody = Font.system(.body, design: .rounded, weight: .regular)
    static let feedHeadline = Font.system(.body, design: .rounded, weight: .semibold)
    static let feedTimestamp = Font.system(.caption, design: .rounded, weight: .medium)
    static let feedBadge = Font.system(.caption2, design: .rounded, weight: .bold)
    static let detailTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let detailBody = Font.system(.body, design: .rounded, weight: .regular)
    static let talkingPointText = Font.system(.callout, design: .rounded, weight: .medium)
    static let settingsItem = Font.system(.body, design: .rounded, weight: .regular)

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
