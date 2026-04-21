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
    var zone2Color: Color = .hotRose
    var collapsedHeight: CGFloat = 120
    @ViewBuilder let zone1Collapsed: () -> CollapsedContent
    @ViewBuilder let zone1Expanded: () -> ExpandedContent

    // Text color on zone 2 depends on background:
    // - Soft blush → charcoal
    // - Hot rose / gold / anything else → black
    private var zone2TextColor: Color {
        zone2Color == .softBlush ? .charcoal : .black
    }

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
                .stroke(Color.hotRose.opacity(isStatic ? 0.7 : 1.0), lineWidth: 2)
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

            VStack(alignment: .leading, spacing: 6) {
                titleRow
                Text(primaryText)
                    .font(.jakarta(15, weight: .bold))
                    .foregroundColor(.warmWhite)
                    .lineLimit(1)

                zone1Collapsed()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: collapsedHeight * 0.7)
    }

    private var zone1ExpandedLayout: some View {
        ZStack {
            Color.deepMauve
            if let tintColor { tintColor }

            VStack(alignment: .leading, spacing: 6) {
                titleRow
                Text(primaryText)
                    .font(.jakarta(15, weight: .bold))
                    .foregroundColor(.warmWhite)

                zone1Expanded()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
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
            zone2Color

            if isExpanded {
                zone2ExpandedContent
            } else {
                zone2CollapsedContent
            }
        }
        .frame(height: isExpanded ? nil : collapsedHeight * 0.3)
        .fixedSize(horizontal: false, vertical: isExpanded)
    }

    private var zone2CollapsedContent: some View {
        HStack {
            if let point = talkingPoint {
                Text(point)
                    .font(.jakarta(13, weight: .regular))
                    .foregroundColor(zone2TextColor)
                    .lineLimit(1)
            } else {
                Text("Tap for more ›")
                    .font(.jakarta(13, weight: .regular))
                    .foregroundColor(zone2TextColor)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var zone2ExpandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let point = talkingPoint {
                Text(zone2Label)
                    .font(.jakarta(13, weight: .bold))
                    .foregroundColor(zone2TextColor)
                Text(point)
                    .font(.jakarta(13, weight: .mediumItalic))
                    .foregroundColor(zone2TextColor)
                    .padding(.bottom, 4)
            }

            HStack {
                Spacer()
                Text("Tap to close ›")
                    .font(.jakarta(11, weight: .regular))
                    .foregroundColor(zone2TextColor.opacity(0.7))
                Spacer()
            }
        }
        .padding(talkingPoint != nil ? 16 : 10)
    }
}
