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

    // Text on light/blush surfaces
    static let charcoal = Color(hex: "#2C2C2C")
    static let mutedText = Color(hex: "#9B8FA0")

    // Derived text colors
    static let textPrimaryOnCard = Color.charcoal
    static let textSecondaryOnCard = Color.mutedText
    static let textTertiary = Color.mutedText

    // Derived utility colors
    static let feedDivider = Color(hex: "#3D2B3E")
    static let cardShadowColor = Color.black.opacity(0.12)
    static let shimmer = Color(hex: "#3D2B3E")

    // Badge colors
    static let badgeMatchday = Color.gold
    static let badgeMatchdayText = Color.charcoal
    static let badgeNews = Color.hotRose
    static let badgeNewsText = Color.warmWhite

    // Post-match card tints (no green — rose for wins, red for losses)
    static let winTint = Color.hotRose.opacity(0.08)
    static let winBar = Color.hotRose.opacity(0.5)
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

// MARK: - Typography (Plus Jakarta Sans)
// Font files bundled in Resources/Fonts/ and registered via Info.plist UIAppFonts.
// PostScript names: PlusJakartaSans-Bold, PlusJakartaSans-SemiBold, PlusJakartaSans-Medium, PlusJakartaSans-Regular,
//                   PlusJakartaSans-Italic, PlusJakartaSans-MediumItalic

extension Font {
    // MARK: - Plus Jakarta Sans helpers
    static func jakarta(_ size: CGFloat, weight: JakartaWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    enum JakartaWeight {
        case regular, medium, semiBold, bold, italic, mediumItalic

        var postScriptName: String {
            switch self {
            case .regular: return "PlusJakartaSans-Regular"
            case .medium: return "PlusJakartaSans-Medium"
            case .semiBold: return "PlusJakartaSans-SemiBold"
            case .bold: return "PlusJakartaSans-Bold"
            case .italic: return "PlusJakartaSans-Italic"
            case .mediumItalic: return "PlusJakartaSans-MediumItalic"
            }
        }
    }

    // MARK: - Semantic tokens

    // Onboarding
    static let onboardingTitle = Font.jakarta(34, weight: .bold)      // ~largeTitle
    static let onboardingBody = Font.jakarta(17, weight: .regular)    // ~body

    // Feed
    static let feedHeadline = Font.jakarta(17, weight: .semiBold)     // ~body semibold
    static let feedTimestamp = Font.jakarta(12, weight: .medium)      // ~caption
    static let feedBadge = Font.jakarta(11, weight: .semiBold)        // ~caption2

    // Detail view
    static let detailTitle = Font.jakarta(22, weight: .bold)          // ~title2
    static let detailBody = Font.jakarta(17, weight: .regular)        // ~body
    static let talkingPointText = Font.jakarta(16, weight: .medium)   // ~callout

    // Section headers
    static let sectionHeader = Font.jakarta(12, weight: .semiBold)    // ~caption

    // Settings
    static let settingsItem = Font.jakarta(17, weight: .regular)      // ~body

    // Immersive card
    static let immersiveHeadline = Font.jakarta(64, weight: .bold)
    static let immersiveContext = Font.jakarta(18, weight: .regular)
    static let immersiveHint = Font.jakarta(13, weight: .regular)
}

// MARK: - Layout Constants

struct Layout {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 10
    static let cardCornerRadius: CGFloat = 16
    static let badgeCornerRadius: CGFloat = 999
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let elementSpacing: CGFloat = 8
    static let buttonHeight: CGFloat = 50
    static let buttonCornerRadius: CGFloat = 16

    // Immersive card zones
    static let immersiveCardHeightRatio: CGFloat = 0.88
    static let immersiveZone1Ratio: CGFloat = 0.65
    static let immersiveZone2Ratio: CGFloat = 0.35
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
            .font(.jakarta(17, weight: .semiBold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.buttonHeight)
            .background(isEnabled ? Color.hotRose : Color.hotRose.opacity(0.4))
            .cornerRadius(Layout.buttonCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
