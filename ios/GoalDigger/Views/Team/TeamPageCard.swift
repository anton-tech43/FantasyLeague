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
        .frame(height: 84)
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
        .frame(height: isExpanded ? nil : 36)
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
