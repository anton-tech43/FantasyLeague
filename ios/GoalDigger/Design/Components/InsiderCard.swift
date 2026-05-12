import SwiftUI

/// The "Things he doesn't know" card. Renders a single InsiderItem in the
/// GoalDigger card language — blush card, hot-rose accent bar, type tracker
/// in the header. Body is collapsible by default (3-line preview) and
/// expands inline on tap. No detail-view navigation; everything reads here.
struct InsiderCard: View {
    let item: InsiderItem
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Vertical rose accent bar — same motif as TalkingPointCard
                // and GlossaryTermSheet. Anchors the card visually.
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.hotRose)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    // Type tracker: small uppercase label + icon
                    HStack(spacing: 6) {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(item.type.label)
                            .font(.sectionHeader)
                            .tracking(1.5)
                    }
                    .foregroundColor(.hotRose)

                    // Title — always visible, full text (capped at 80 chars
                    // by the post script, so no truncation needed)
                    Text(item.title)
                        .font(.jakarta(17, weight: .semiBold))
                        .foregroundColor(.textPrimaryOnCard)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Body — collapsed shows ~2 lines, expanded shows all.
                    Text(item.body)
                        .font(.jakarta(15, weight: .regular))
                        .foregroundColor(.textSecondaryOnCard)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: isExpanded)

                    // "Read more" affordance when collapsed. Only show if
                    // body is plausibly longer than 2 lines (>110 chars).
                    // Cheap heuristic; avoids the chevron flashing on
                    // genuinely-short bodies.
                    if !isExpanded && item.body.count > 110 {
                        HStack(spacing: 4) {
                            Text("Read more")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.jakarta(13, weight: .medium))
                        .foregroundColor(.hotRose)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.label) about your team: \(item.title)")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to read more")
    }
}
