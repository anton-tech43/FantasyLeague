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

/// Live Activity for an in-progress match of a followed team (WC country or PL
/// club): live score on the Lock Screen + Dynamic Island, started at kickoff
/// and updated via backend pushes through to full-time. Clubs have no flag
/// emoji, so the flag slots collapse and the compact leading shows a 3-letter
/// code instead.
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
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
                        MatchMinute(state: context.state, size: 11, isStale: context.isStale)
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
                if context.attributes.homeFlag.isEmpty {
                    Text(context.attributes.homeName.prefix(3).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LA.warmWhite)
                } else {
                    Text(context.attributes.homeFlag)
                }
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
            if !flag.isEmpty { Text(flag).font(.system(size: 22)) }
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LA.warmWhite)
                .lineLimit(1)
        }
    }

}

/// Lock Screen / banner presentation. Home — score — away on one row, status +
/// optional note below.
private struct LockScreenView: View {
    let attributes: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState
    var isStale = false

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
                    MatchMinute(state: state, size: 12, isStale: isStale)
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
            if !flag.isEmpty { Text(flag).font(.system(size: 34)) }
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LA.warmWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The match minute. During a half it runs on its own from `clockStart` — a
/// Live Activity cannot be redrawn every minute by push without iOS throttling
/// it, and a throttled activity freezes the minute and delays the goal too.
/// Outside a half (HT, FT, penalties) it is the period label.
private struct MatchMinute: View {
    let state: MatchActivityAttributes.ContentState
    let size: CGFloat
    /// No update reached it for a while (a lost end push, no signal): the
    /// score is the last one we know, so the clock must not look live.
    var isStale = false

    /// The minute at render time — only picks the width and the "/ 90"; the
    /// digits themselves come from the running timer.
    private var minutesNow: Int {
        guard let start = state.clockStartDate else { return 0 }
        return Int(Date().timeIntervalSince(start) / 60)
    }

    var body: some View {
        Group {
            if isStale {
                Text("LAST UPDATE")
            } else if let start = state.clockStartDate {
                HStack(spacing: 0) {
                    // Renders "63:12". On a dimmed lock screen iOS shows
                    // "63:--" — its own rule for every running timer. (A
                    // minutes-only version by clipping the timer text was
                    // tried 2026-10-27 and does not render reliably.)
                    Text(timerInterval: start...start.addingTimeInterval(150 * 60),
                         countsDown: false, showsHours: false)
                        .monospacedDigit()
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        // Timer text claims the widest width it could need; pin it.
                        // Sized for three digits from 85': no push may arrive before 100'.
                        .frame(width: size * (minutesNow >= 85 ? 4.4 : 3.7), alignment: .trailing)
                    if minutesNow < 90 { Text(" / 90") }
                }
            } else {
                Text(state.badgeText)
            }
        }
        .font(.system(size: size, weight: .bold))
        .foregroundStyle(LA.hotRose)
    }
}
