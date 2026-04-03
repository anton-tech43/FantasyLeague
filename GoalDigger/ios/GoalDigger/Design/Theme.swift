import SwiftUI

// MARK: - Goal Digger Design System
// "Relationship Translator" editorial design language.
// Warm, approachable palette with serif headlines for an editorial feel.
// Targets partners who want to connect through football conversations.
//
// Design decisions documented for other agents:
// - Serif headlines (.serif design) give editorial/magazine warmth
// - Dusty terracotta replaces bright orange for sophistication
// - Gradient CTA buttons add visual energy to key actions
// - Mood tinting on cards ties emotional context to visual feedback
// - Card borders (dusty rose) replace heavy shadows for lighter feel

enum Theme {
    // MARK: - Colors — Warm Editorial Palette

    /// Warm cream background — feels like stationery, not a sports app
    static let appBackground = Color(hex: "FAF5EF")

    /// Cards stay white for contrast against warm background
    static let cardBackground = Color.white

    /// Subtle warm divider
    static let feedDivider = Color(hex: "F0ECE6")

    /// Text hierarchy: primary → secondary → tertiary
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "8A8480")
    static let textTertiary = Color(hex: "B8B2AA")

    /// Dusty terracotta — the signature accent, warmer than before
    static let accentWarm = Color(hex: "C4785A")

    /// Soft peach for badge backgrounds and subtle highlights
    static let accentSoft = Color(hex: "EACFC0")

    /// Muted sage green — less "sporty", more editorial
    static let accentGreen = Color(hex: "8EAE7E")

    /// Dusty rose — card borders, subtle emphasis
    static let dustyRose = Color(hex: "EACFC0")

    /// Peach highlight for warm accents
    static let peach = Color(hex: "E8B796")

    /// Shadow and shimmer
    static let cardShadow = Color.black.opacity(0.04)
    static let shimmer = Color(hex: "F5F0EA")

    // MARK: - Mood Tint Colors
    // Maps to emotionalContext from the API. Subtle background tints on cards.

    static let moodExcited = Color(hex: "E8B796").opacity(0.12)
    static let moodNervous = Color(hex: "EACFC0").opacity(0.15)
    static let moodConfident = Color(hex: "8EAE7E").opacity(0.10)
    static let moodDefault = Color.clear

    // MARK: - Typography
    // Serif headlines give editorial/magazine feel.
    // Body text stays rounded for readability.

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
    static let conversationStarter = Font.system(.subheadline, design: .serif, weight: .medium).italic()
    static let greetingTitle = Font.system(.title3, design: .serif, weight: .semibold)

    // MARK: - Spacing (unchanged)

    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8

    // MARK: - Gradient CTA

    /// Warm gradient for primary CTA buttons
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "C4785A"), Color(hex: "E8B796")],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Background gradient — subtle warmth from top to bottom
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "FAF5EF"), Color(hex: "F5EDE4")],
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
                    .stroke(Theme.dustyRose.opacity(0.3), lineWidth: 1)
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
            .background(Theme.ctaGradient)
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
