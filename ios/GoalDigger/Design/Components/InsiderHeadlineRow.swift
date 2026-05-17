import SwiftUI

/// Compact insider row used by the "Things he doesn't know" section on
/// the team page. Renders the type tracker (small uppercase rose) and
/// the headline only — no body, no expand.
///
/// The full `InsiderCard` with title + body lives elsewhere (FeedView
/// empty state) for surfaces where the explanation matters. The team
/// page section stacks 4 of these rows (stat / history / oddity /
/// anecdote, latest of each type) to give variety at a glance without
/// asking the user to expand anything.
struct InsiderHeadlineRow: View {
    let item: InsiderItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Same vertical rose accent as InsiderCard — visual continuity
            // with the rest of the team-page cards.
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.hotRose)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.type.iconName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(item.type.label)
                        .font(.sectionHeader)
                        .tracking(1.5)
                }
                .foregroundColor(.hotRose)

                Text(item.title)
                    .font(.jakarta(15, weight: .semiBold))
                    .foregroundColor(.textPrimaryOnCard)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.label) about your team: \(item.title)")
    }
}
