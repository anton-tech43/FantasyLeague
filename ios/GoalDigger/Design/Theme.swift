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
    // mutedText, darkened at the same hue: #9B8FA0 on softBlush is 2.76:1,
    // this is 4.74:1 (WCAG AA for body text). mutedText itself stays, it is
    // 5.2:1 on deepMauve and the dark surfaces use it.
    static let textSecondaryOnCard = Color(hex: "#75677A")
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

    // Answer states on a multiple-choice option. Green is for a right answer
    // and nothing else in the app, so it reads as "that one" at a glance.
    static let answerRight = Color(hex: "#CDEBD3")
    static let answerRightInk = Color(hex: "#2E8B4E")
    static let answerWrong = Color(hex: "#F9C9CE")
    static let answerWrongInk = Color(hex: "#D23A4A")

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
        case regular, medium, semiBold, bold, extraBold, italic, mediumItalic, boldItalic

        var postScriptName: String {
            switch self {
            case .regular: return "PlusJakartaSans-Regular"
            case .medium: return "PlusJakartaSans-Medium"
            case .semiBold: return "PlusJakartaSans-SemiBold"
            case .bold: return "PlusJakartaSans-Bold"
            case .extraBold: return "PlusJakartaSans-ExtraBold"
            case .italic: return "PlusJakartaSans-Italic"
            case .mediumItalic: return "PlusJakartaSans-MediumItalic"
            case .boldItalic: return "PlusJakartaSans-BoldItalic"
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

    // Immersive card — League Spartan Black for bold impact headlines
    static let immersiveHeadline = Font.custom("LeagueSpartan-Black", size: 64)
    // Called it — the one big line on every card in the slip sequence (cover,
    // the yes/no cards) and on the pink round hero. Same face as the immersive
    // headline. Sized at 40 so the longest fixed line ("Get ready for") and a
    // wrapping opponent name ("Before Chelsea") both fit without
    // minimumScaleFactor kicking in — that auto-shrink is what made the two
    // full-screen cards render at different sizes.
    static let calledItHeadline = Font.custom("LeagueSpartan-Black", size: 40)
    static let immersiveContext = Font.jakarta(18, weight: .regular)

    // Matchday › After (Anton's design, 2026-10-07): the score and the
    // scorer's name in League Spartan Bold, the verdict in a serif.
    static func spartanBold(_ size: CGFloat) -> Font { .custom("LeagueSpartan-Bold", size: size) }
    static func garamond(_ size: CGFloat) -> Font { .custom("CormorantGaramond-Medium", size: size) }
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

    // Immersive card zones — 65% dark (headline + analogy + hint), 35% pink
    // (Your move). The card extends behind the tab bar at full screen height,
    // so zone 2 needs ~35% to keep its label + 2-line talking point fully
    // readable above the tab bar with breathing room.
    static let immersiveCardHeightRatio: CGFloat = 1.0
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
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            // minHeight: a fixed 50 clipped the label at accessibility text sizes.
            .frame(minHeight: Layout.buttonHeight)
            .background(isEnabled ? Color.hotRose : Color.hotRose.opacity(0.4))
            .cornerRadius(Layout.buttonCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A Spacer-laid-out screen that scrolls only when it has to. The content is
/// given at least the full height, so its Spacers lay it out exactly as a
/// plain VStack would; at accessibility text sizes or with the keyboard up it
/// runs taller than that and scrolls instead of pushing off the screen.
struct FittingScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content.frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// The system switch on a softBlush card. Its off-track is a translucent grey
/// that all but vanishes on blush (1.5:1), leaving a white knob on a white-ish
/// card. A mutedText capsule behind the translucent track darkens it to about
/// 3:1; when on, the opaque rose track covers it. Still the native Toggle, so
/// VoiceOver and the tap target are unchanged.
struct CardToggleStyle: ToggleStyle {
    @MainActor private static let switchSize = UISwitch().intrinsicContentSize

    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .tint(.hotRose)
            .background(alignment: .trailing) {
                Capsule()
                    .fill(Color.mutedText)
                    .frame(width: Self.switchSize.width, height: Self.switchSize.height)
            }
    }
}
