import SwiftUI
import UIKit

struct TeamPageCard<CollapsedContent: View, ExpandedContent: View>: View {
    let title: String
    let primaryText: String
    let zone2Label: String
    let talkingPoint: String?
    var isStatic: Bool = false
    let isExpanded: Bool
    let onTap: () -> Void
    var tintColor: Color? = nil
    /// When the collapsed `primaryText` is a preview of the expanded body
    /// (season summary, rivalry blurb, post-match text), showing both means
    /// she reads the same opening twice. Set this and the expanded layout
    /// shows the body under the title only.
    var hidePrimaryWhenExpanded: Bool = false
    /// Optional round image on the right of the header (the manager's
    /// headshot). Nil = no image, layout unchanged.
    var leadingImageURL: URL? = nil
    /// The collapsed footer. Nil, the default, teases the talking point and
    /// falls back to "Tap for more ›". A card that opens onto something
    /// specific names it instead ("Pre game talk ›") and goes on naming it
    /// once it has a talking point to show inside.
    var footerLabel: String? = nil
    @ViewBuilder let zone1Collapsed: () -> CollapsedContent
    @ViewBuilder let zone1Expanded: () -> ExpandedContent
    /// One line at the usual sizes; at the accessibility sizes the collapsed
    /// lines wrap instead ("Leeds (HO…" at the largest size).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var collapsedLineLimit: Int? { dynamicTypeSize.isAccessibilitySize ? nil : 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Zone 1 — deepMauve content area. Collapsed, it is one button
            // to VoiceOver; open, its lines read one by one and zone 2 is
            // the button that closes it.
            zone1View
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .modifier(TapZoneAccessibility(isButton: !isExpanded, isExpanded: isExpanded, action: onTap))

            // Zone 2 — hotRose talking point area
            zone2View
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .modifier(TapZoneAccessibility(isButton: true, isExpanded: isExpanded, action: onTap))
        }
        .cornerRadius(16)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.hotRose.opacity(isStatic ? 0.5 : 1.0), lineWidth: 2)
                .padding(1)
        )
    }

    // MARK: - Zone 1

    @ViewBuilder
    private var zone1View: some View {
        if isExpanded {
            zone1ExpandedLayout
        } else {
            zone1CollapsedLayout
        }
    }

    private var zone1CollapsedLayout: some View {
        ZStack {
            Color.deepMauve
            if let tintColor { tintColor }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    titleRow
                    Text(primaryText)
                        .font(.jakarta(15, weight: .bold))
                        .foregroundColor(.warmWhite)
                        .lineLimit(collapsedLineLimit)

                    zone1Collapsed()
                }
                if leadingImageURL != nil {
                    Spacer(minLength: 0)
                    headerImage(size: 44)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // minHeight, not height: at accessibility text sizes a hard 84 clipped
        // the title, the primary line and the chips against the card border.
        .frame(minHeight: 84)
    }

    private var zone1ExpandedLayout: some View {
        ZStack {
            Color.deepMauve
            if let tintColor { tintColor }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        titleRow
                        if !hidePrimaryWhenExpanded {
                            Text(primaryText)
                                .font(.jakarta(15, weight: .bold))
                                .foregroundColor(.warmWhite)
                        }
                    }
                    if leadingImageURL != nil {
                        Spacer(minLength: 0)
                        headerImage(size: 56)
                    }
                }

                zone1Expanded()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Circular headshot with the same fallback the player rows use.
    @ViewBuilder
    private func headerImage(size: CGFloat) -> some View {
        ZStack {
            // A badge sits on a light disc: Spurs' navy vanished on mauve.
            Circle().fill(leadingImageURL?.path.contains("/teams/") == true
                          ? Color.cardBackground : Color.hotRose.opacity(0.15))
            AsyncImage(url: leadingImageURL) { phase in
                if case .success(let image) = phase {
                    // A club badge is shown whole; a headshot fills the circle.
                    if leadingImageURL?.path.contains("/teams/") == true {
                        image.resizable().scaledToFit().padding(size * 0.14)
                    } else {
                        image.resizable().scaledToFill()
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundColor(.hotRose.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var titleRow: some View {
        Text(title.uppercased())
            .font(.jakarta(11, weight: .semiBold))
            .tracking(0.5)
            .foregroundColor(.mutedText)
    }

    // MARK: - Zone 2

    private var zone2View: some View {
        ZStack {
            Color.hotRose

            if isExpanded {
                zone2ExpandedContent
            } else {
                zone2CollapsedContent
            }
        }
        .frame(minHeight: isExpanded ? nil : 36)
        .fixedSize(horizontal: false, vertical: isExpanded)
    }

    private var zone2CollapsedContent: some View {
        HStack {
            Text(footerLabel ?? talkingPoint ?? "Tap for more ›")
                .font(.jakarta(13, weight: .regular))
                .foregroundColor(.warmWhite)
                .lineLimit(collapsedLineLimit)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var zone2ExpandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let point = talkingPoint {
                Text(zone2Label)
                    .font(.jakarta(13, weight: .bold))
                    .foregroundColor(.warmWhite)
                Text(point)
                    .font(.jakarta(13, weight: .mediumItalic))
                    .foregroundColor(.warmWhite)
                    .padding(.bottom, 4)
            }

            HStack {
                Spacer()
                Text("Tap to close ›")
                    .font(.jakarta(11, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.7))
                Spacer()
            }
        }
        .padding(talkingPoint != nil ? 16 : 10)
    }
}

/// A tappable zone of the card, as VoiceOver sees it: one combined button that
/// says whether the card is open. When `isButton` is false (an open zone 1,
/// whose lines may hold their own controls) nothing is changed.
private struct TapZoneAccessibility: ViewModifier {
    let isButton: Bool
    let isExpanded: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isButton {
            content
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityAction { action() }
        } else {
            content
        }
    }
}

// MARK: - Bundled portraits

/// Black-and-white portraits bundled in the app, found by name: the asset for
/// a man is `bw-<club id>-<key>`, where the key is his folded surname
/// ("bw-arsenal-odegaard"), or his whole folded name when two men in the
/// squad share a surname. `tools/portraits/import.py` writes them under the
/// same rule, off the label printed on each sticker, so a new club or a new
/// signing is an import and no code (Anton, 2026-10-02).
// ponytail: bundled in the app. If the look sticks for every club, the images
// move to storage with a column on `players`.
enum PlayerPortrait {
    // Packs are built off the main actor too, so the cache takes a lock
    // rather than an actor. `UIImage(named:)` is safe from any thread.
    nonisolated(unsafe) private static var known: [String: Bool] = [:]
    private static let lock = NSLock()

    private static func exists(_ asset: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let hit = known[asset] { return hit }
        let hit = UIImage(named: asset) != nil
        known[asset] = hit
        return hit
    }

    static func asset(club: String?, name: String) -> String? {
        guard let club else { return nil }
        let candidates = [fullKey(name), surname(name)].compactMap { $0 }.map { "bw-\(club)-\($0)" }
        return candidates.first(where: exists)
    }

    /// Marks a quiz image as a bundled asset rather than a URL.
    static let scheme = "asset:"

    /// `asset(...)` as a quiz image string, which is otherwise a URL.
    static func source(club: String?, name: String) -> String? {
        asset(club: club, name: name).map { scheme + $0 }
    }

    static func assetName(_ source: String?) -> String? {
        guard let source, source.hasPrefix(scheme) else { return nil }
        return String(source.dropFirst(scheme.count))
    }

    /// Folded, and ø spelled o: it has no decomposition, so diacritic
    /// folding leaves "Ødegaard" as "ødegaard".
    static func surname(_ name: String) -> String? {
        folded(name).split(separator: " ").last.map(String.init)
    }

    /// "Ryan Christie" → "ryan-christie", for the club with two Christies.
    static func fullKey(_ name: String) -> String? {
        let parts = folded(name).split(separator: " ")
        return parts.count > 1 ? parts.joined(separator: "-") : nil
    }

    private static func folded(_ name: String) -> String {
        let f = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en"))
            .lowercased().replacingOccurrences(of: "ø", with: "o").replacingOccurrences(of: "æ", with: "ae")
        return String(f.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : " " })
            .split(separator: " ").joined(separator: " ")
    }

    #if DEBUG
    static func selfCheck() -> Bool {
        asset(club: "arsenal", name: "Mikel Arteta") == "bw-arsenal-arteta"
            && asset(club: "chelsea", name: "Mikel Arteta") == nil
            && surname("M. Ødegaard") == "odegaard"
            && asset(club: "arsenal", name: "M. Ødegaard") == "bw-arsenal-odegaard"
            && asset(club: "arsenal", name: "Gabriel Magalhães") == "bw-arsenal-magalhaes"
            && asset(club: "arsenal", name: "M. Lewis-Skelly") == "bw-arsenal-lewis-skelly"
            && asset(club: "arsenal", name: "V. Gyökeres") == "bw-arsenal-gyokeres"
            && asset(club: "arsenal", name: "Kepa") == "bw-arsenal-kepa"
            && asset(club: "arsenal", name: "P. Hincapié") == "bw-arsenal-hincapie"
            && assetName(source(club: "arsenal", name: "Mikel Arteta")) == "bw-arsenal-arteta"
            && assetName("https://media.api-sports.io/x.png") == nil
    }
    #endif
}
