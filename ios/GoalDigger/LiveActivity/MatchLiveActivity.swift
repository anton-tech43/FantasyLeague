import ActivityKit
import WidgetKit
import SwiftUI

// GoalDigger brand palette (inlined — the widget target doesn't share the
// app's Theme.swift).
private enum LA {
    static let deepMauve = Color(red: 45 / 255, green: 27 / 255, blue: 46 / 255)
    static let hotRose = Color(red: 232 / 255, green: 57 / 255, blue: 125 / 255)
    static let warmWhite = Color(red: 245 / 255, green: 240 / 255, blue: 240 / 255)
    static let warmWhiteDim = Color(red: 245 / 255, green: 240 / 255, blue: 240 / 255).opacity(0.6)
}

/// Live Activity for an in-progress World Cup match: live score on the Lock
/// Screen + Dynamic Island, started at kickoff and updated via backend pushes
/// through to full-time.
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(LA.deepMauve)
                .activitySystemActionForegroundColor(LA.hotRose)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    sideLabel(flag: context.attributes.homeFlag, name: context.attributes.homeName)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    sideLabel(flag: context.attributes.awayFlag, name: context.attributes.awayName)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(context.state.homeScore) - \(context.state.awayScore)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(LA.warmWhite)
                        statusBadge(context.state.badgeText)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let note = context.state.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LA.warmWhiteDim)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            } compactLeading: {
                Text(context.attributes.homeFlag)
            } compactTrailing: {
                Text("\(context.state.homeScore)-\(context.state.awayScore)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LA.hotRose)
            } minimal: {
                Text("\(context.state.homeScore)-\(context.state.awayScore)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(LA.hotRose)
            }
            .keylineTint(LA.hotRose)
        }
    }

    private func sideLabel(flag: String, name: String) -> some View {
        VStack(spacing: 2) {
            Text(flag).font(.system(size: 22))
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LA.warmWhite)
                .lineLimit(1)
        }
    }

    private func statusBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(LA.hotRose)
    }
}

/// Lock Screen / banner presentation. Home — score — away on one row, status +
/// optional note below.
private struct LockScreenView: View {
    let attributes: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            if let group = attributes.groupLabel, !group.isEmpty {
                Text(group.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LA.warmWhiteDim)
            }
            HStack(alignment: .center, spacing: 12) {
                teamColumn(flag: attributes.homeFlag, name: attributes.homeName)
                VStack(spacing: 3) {
                    Text("\(state.homeScore) - \(state.awayScore)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(LA.warmWhite)
                    Text(state.badgeText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LA.hotRose)
                }
                .frame(minWidth: 96)
                teamColumn(flag: attributes.awayFlag, name: attributes.awayName)
            }
            if let note = state.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LA.warmWhiteDim)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(14)
    }

    private func teamColumn(flag: String, name: String) -> some View {
        VStack(spacing: 4) {
            Text(flag).font(.system(size: 34))
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LA.warmWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
