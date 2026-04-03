import SwiftUI

// MARK: - Goal Digger Design System
// "Soft intel" — warm, editorial, intimate. Vogue meets WhatsApp.
// Relationship-coded, not sports-coded.
//
// Design decisions documented for other agents:
// - Serif headlines (.serif design) give editorial/magazine warmth
// - Pink (#E8A0BF) and peach (#FFD6C4) are the signature palette — feminine, warm
// - Gradient CTA buttons use pink→peach for visual energy
// - Mood tinting on cards ties emotional context to visual feedback
// - Card borders use soft terracotta for stationery feel
// - Bigger corners (18pt) and spacing (14pt) for modern, airy layout

enum Theme {
    // MARK: - Colors — Warm Editorial Palette

    /// Warm cream background — feels like stationery, not a sports app
    static let appBackgroundTop = Color(hex: "FAF5EF")
    static let appBackgroundBottom = Color(hex: "F5EDE4")
    static let appBackground = Color(hex: "FAF5EF")

    /// Barely-warm white card — not pure white, warmer
    static let cardBackground = Color(hex: "FFFBF7")

    /// Warm tinted card for quiet states (freshness etc.)
    static let cardBackgroundAlt = Color(hex: "F7F0E8")

    /// Soft terracotta card border
    static let cardBorder = Color(hex: "D4A989").opacity(0.25)

    /// Subtle warm divider
    static let feedDivider = Color(hex: "EDE5DA")

    /// Text hierarchy: warm near-black → warm brown-gray → light warm gray
    static let textPrimary = Color(hex: "2C2420")
    static let textSecondary = Color(hex: "8A7D74")
    static let textTertiary = Color(hex: "B5A99E")

    /// Dusty terracotta — primary accent
    static let accentWarm = Color(hex: "C4785A")

    /// Signature pink — #E8A0BF — badges, highlights, personality
    static let accentPink = Color(hex: "E8A0BF")

    /// Signature peach — #FFD6C4 — CTA gradients, warm highlights
    static let accentPeach = Color(hex: "FFD6C4")

    /// Dusty rose — badge backgrounds, soft emphasis
    static let accentSoft = Color(hex: "EACFC0")

    /// Muted sage green — matchday, not sporty
    static let accentGreen = Color(hex: "8EAE7E")

    /// Shadow and shimmer
    static let cardShadow = Color(hex: "C4785A").opacity(0.06)
    static let shimmer = Color(hex: "F0E8DF")

    // MARK: - Mood Tint Colors
    // Subtle card background tints keyed to emotionalContext from API.

    static let moodExciting = Color(hex: "FFF5EC")
    static let moodBadNews = Color(hex: "F5F0ED")
    static let moodDrama = Color(hex: "F8F0F5")
    static let moodFunny = Color(hex: "FDFAEC")

    // MARK: - Typography
    // Serif for editorial warmth on headlines, rounded sans for readability.

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
    static let greetingTitle = Font.system(.title3, design: .serif, weight: .semibold)

    // MARK: - Spacing — airy, modern

    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let cardSpacing: CGFloat = 14
    static let cardCornerRadius: CGFloat = 18
    static let cardShadowRadius: CGFloat = 10
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8

    // MARK: - Gradients

    /// Background gradient — subtle warmth from top to bottom
    static let backgroundGradient = LinearGradient(
        colors: [appBackgroundTop, appBackgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Card Style Modifier
// Supports optional mood tinting — cards glow faintly based on emotional context.
// Border overlay gives editorial "stationery" feel.

struct CardStyle: ViewModifier {
    var moodTint: Color?

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

// MARK: - Gradient CTA Button Style

struct GradientButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.feedHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.accentPink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func gradientButton() -> some View {
        modifier(GradientButtonStyle())
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
