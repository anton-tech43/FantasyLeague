import SwiftUI

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

    var body: some View {
        VStack(spacing: 0) {
            // Zone 1 — deepMauve content area
            zone1View
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            // Zone 2 — hotRose talking point area
            zone2View
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
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
                        .lineLimit(1)

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
            Circle().fill(Color.hotRose.opacity(0.15))
            AsyncImage(url: leadingImageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
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
                .lineLimit(1)
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

// MARK: - Bundled portraits

/// Black-and-white portraits bundled in the app: a test on Arsenal (Anton,
/// 2026-10-01). Keyed by club id and folded surname, the same surname rule the
/// squad pack matches dossiers on, so "M. Ødegaard" and "Martin Ødegaard" are
/// one man.
// ponytail: bundled for one club, by hand. If the look sticks, the images move
// to storage with a column on `players` and this table goes.
enum PlayerPortrait {
    private static let table: [String: [String: String]] = [
        "arsenal": [
            "arteta": "bw-arsenal-arteta",
        ],
    ]

    /// Marks a quiz image as a bundled asset rather than a URL.
    static let scheme = "asset:"

    static func asset(club: String?, name: String) -> String? {
        guard let club, let byName = table[club], let key = surname(name) else { return nil }
        return byName[key]
    }

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
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en"))
            .lowercased().replacingOccurrences(of: "ø", with: "o")
            .split(separator: " ").last.map(String.init)
    }

    #if DEBUG
    static func selfCheck() -> Bool {
        asset(club: "arsenal", name: "Mikel Arteta") == "bw-arsenal-arteta"
            && asset(club: "chelsea", name: "Mikel Arteta") == nil
            && surname("M. Ødegaard") == "odegaard"
            && assetName(source(club: "arsenal", name: "Mikel Arteta")) == "bw-arsenal-arteta"
            && assetName("https://media.api-sports.io/x.png") == nil
    }
    #endif
}
