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
        // V2.0 dual-fandom: include both country and team if set. Country
        // comes first (V2.0 anchor) so the dropdown's first row matches
        // AppState's default activeContext picker (country > team).
        var result: [FeedContext] = []
        if let country = appState.selectedCountry {
            result.append(.country(country))
        }
        if let team = appState.selectedTeam {
            result.append(.team(team))
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
            // Club badge (16x16) — use first letter as placeholder
            Text(String(team.shortName.prefix(2)).uppercased())
                .font(.jakarta(10, weight: .bold))
                .foregroundColor(isSelected ? .hotRose : .warmWhite.opacity(0.6))
                .frame(width: 16, height: 16)
        case .country(let country):
            // National team — same initials pattern. Future: render flag crest.
            Text(String(country.shortName.prefix(2)).uppercased())
                .font(.jakarta(10, weight: .bold))
                .foregroundColor(isSelected ? .hotRose : .warmWhite.opacity(0.6))
                .frame(width: 16, height: 16)
        case .everyoneTalking:
            Image(systemName: "soccerball")
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
