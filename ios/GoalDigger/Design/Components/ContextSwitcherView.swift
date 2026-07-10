import SwiftUI

/// Compact floating dropdown for switching feed contexts.
/// Anchored below the toolbar, left-aligned.
struct ContextSwitcherView: View {
    let appState: AppState
    let teamItems: [ContentItem]
    let everyoneItems: [ContentItem]
    let onSelect: (FeedContext) -> Void
    let onDismiss: () -> Void

    private var contexts: [FeedContext] {
        // V2.2 multi-fandom: one row per followed country, then per followed
        // club, then Everyone. Countries come first (the WC anchor) so the
        // first row matches AppState's default activeContext picker.
        var result: [FeedContext] = []
        result.append(contentsOf: appState.selectedCountries.map { .country($0) })
        result.append(contentsOf: appState.selectedTeams.map { .team($0) })
        // Tournament-wide feed, visible for everyone during the World
        // Championship; self-hides after the final (WCSeason gate).
        if WCSeason.isVisible {
            result.append(.worldChampionship)
        }
        result.append(.everyoneTalking)
        return result
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full-screen transparent tap catcher for dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // Dropdown
            VStack(spacing: 0) {
                ForEach(Array(contexts.enumerated()), id: \.element) { _, context in
                    contextRow(context)
                    if context != contexts.last {
                        Divider()
                            .background(Color.hotRose.opacity(0.15))
                    }
                }
            }
            .background(Color.deepMauve)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.hotRose.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
            .padding(.leading, Layout.screenPadding)
            .padding(.top, 8)
        }
    }

    private func contextRow(_ context: FeedContext) -> some View {
        let isSelected = context == appState.activeContext

        return Button {
            onSelect(context)
        } label: {
            HStack(spacing: 12) {
                // Left border indicator for selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.hotRose)
                        .frame(width: 3, height: 24)
                } else {
                    Color.clear.frame(width: 3, height: 24)
                }

                // Icon
                contextIcon(context, isSelected: isSelected)

                // Label
                Text(context.dropdownLabel)
                    .font(.jakarta(17, weight: isSelected ? .semiBold : .regular))
                    .foregroundColor(isSelected ? .hotRose : .warmWhite.opacity(0.6))
                    .lineLimit(1)

                Spacer()

                // Unread badge (hidden on active context)
                if !isSelected {
                    unreadBadge(for: context)
                }
            }
            .padding(.trailing, 16)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextIcon(_ context: FeedContext, isSelected: Bool) -> some View {
        switch context {
        case .team(let team):
            // Real club crest (matches the toolbar pill), 16x16.
            TeamCrestView(team: team, size: 16)
        case .country(let country):
            TeamCrestView(country: country, size: 16)
        case .worldChampionship, .everyoneTalking:
            Image(systemName: context.iconName)
                .font(.system(size: 14))
                .foregroundColor(.hotRose)
                .frame(width: 16, height: 16)
        }
    }

    @ViewBuilder
    private func unreadBadge(for context: FeedContext) -> some View {
        let items: [ContentItem] = {
            switch context {
            case .team, .country: return teamItems
            // The switcher only receives the active entity's items +
            // everyone items; WC items aren't loaded until the context is
            // opened, so it shows no badge. Acceptable minimal wiring.
            case .worldChampionship: return []
            case .everyoneTalking: return everyoneItems
            }
        }()
        let badgeText = UnreadTracker.shared.badgeText(for: context, items: items)

        if let text = badgeText {
            Text(text)
                .font(.jakarta(11, weight: .bold))
                .foregroundColor(.warmWhite)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.hotRose)
                .clipShape(Capsule())
        }
    }
}
