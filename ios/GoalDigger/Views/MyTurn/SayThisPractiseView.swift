import SwiftUI

// MARK: - The draw
//
// Ten situations a session, no repeats, weighted towards "How it's going".
// Anton's reasoning (2026-09-09): a match state lasts minutes, so she has time
// to use a line for it. A moment lasts seconds. So half the session is match
// states and the other half is split between the two.
//
// Pure and deterministic given a seed, so the split can be asserted.

/// How many of each group a ten-situation session aims for. Fixed order so the
/// draw does not depend on dictionary iteration order.
let sayThisPractiseQuotas: [(SituationGroup, Int)] = [(.howItsGoing, 5), (.moments, 3), (.whenHeAsks, 2)]

/// SplitMix64. Small, seedable, and good enough to shuffle 25 things.
struct SayThisSeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// The ten situation ids for one practise session, in the order she meets them.
/// A group short of its quota is topped up from whatever is left over.
func sayThisPractiseIds(situations: [Situation], seed: UInt64, count: Int = 10) -> [String] {
    var rng = SayThisSeededRNG(seed: seed)
    var picked: [String] = []
    var leftover: [String] = []
    for (group, quota) in sayThisPractiseQuotas {
        let pool = situations.filter { $0.group == group }.map(\.id).shuffled(using: &rng)
        picked += pool.prefix(quota)
        leftover += pool.dropFirst(quota)
    }
    picked += leftover.shuffled(using: &rng).prefix(max(0, count - picked.count))
    return Array(picked.prefix(count)).shuffled(using: &rng)
}

#if DEBUG
/// Runnable check, fired once per session start in debug builds: the draw is
/// deterministic for a seed, never repeats a situation, and with the shipped
/// 25 situations splits 5 "How it's going" / 3 Moments / 2 "When he asks you".
func sayThisPractiseSelfCheck(_ situations: [Situation]) {
    guard sayThisPractiseQuotas.allSatisfy({ quota in situations.filter { $0.group == quota.0 }.count >= quota.1 }) else { return }
    let a = sayThisPractiseIds(situations: situations, seed: 7)
    assert(a == sayThisPractiseIds(situations: situations, seed: 7), "draw must be deterministic for a seed")
    assert(Set(a).count == a.count && a.count == 10, "draw must be ten distinct situations, got \(a)")
    let groups = Dictionary(grouping: situations.filter { a.contains($0.id) }, by: \.group).mapValues(\.count)
    assert(groups[.howItsGoing] == 5 && groups[.moments] == 3 && groups[.whenHeAsks] == 2, "weighting drifted: \(groups)")
}
#endif

/// One practise session. Lives as `@State` in `SayThisView`: the module views
/// stay mounted while the app runs, so a session survives a segment switch and
/// does not need to survive a relaunch.
struct SayThisPractiseSession {
    var ids: [String]
    var index: Int = 0
    var revealed: Bool = false
    var finished: Bool = false

    init(situations: [Situation], seed: UInt64 = .random(in: 0..<UInt64.max)) {
        ids = sayThisPractiseIds(situations: situations, seed: seed)
        #if DEBUG
        sayThisPractiseSelfCheck(situations)
        #endif
    }

    /// "Continue · 4 of 10" on the practise button while a session is open.
    var positionLabel: String { "\(min(index + 1, ids.count)) of \(ids.count)" }
}

// MARK: - The screen

/// Practise: a situation comes up, she has a go in her head, then Reveal shows
/// the lines. No scoring and no right answer — the point is exposure, so that
/// the words are not brand new when the match is on.
struct SayThisPractiseView: View {
    let situations: [Situation]
    let lingoById: [String: LingoTerm]
    @Bindable var store: MyTurnStore
    @Binding var session: SayThisPractiseSession
    /// Picked once when the session ends; the session itself is @State in the
    /// parent and does not outlive the tab, so this does not need to either.
    @State private var hype: String?
    /// Stop mid-session: keeps the round, drops back to the bank.
    let onStop: () -> Void
    /// Done with the ten: clears the round.
    let onFinishedExit: () -> Void
    let onRestart: () -> Void

    private var current: Situation? {
        guard session.index < session.ids.count else { return nil }
        return situations.first { $0.id == session.ids[session.index] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            if session.finished {
                finishedView
            } else if let situation = current {
                questionView(situation)
            }
        }
    }

    // MARK: A situation

    @ViewBuilder
    private func questionView(_ situation: Situation) -> some View {
        HStack {
            Text(session.positionLabel)
                .font(.jakarta(13, weight: .semiBold))
                .foregroundColor(.warmWhite.opacity(0.6))
            Spacer(minLength: 0)
            Button(action: onStop) {
                Text("Stop")
                    .font(.jakarta(14, weight: .semiBold))
                    .foregroundColor(.warmWhite.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)

        Text(situation.group.title.uppercased())
            .font(.jakarta(10, weight: .bold))
            .tracking(1)
            .foregroundColor(.hotRose)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.hotRose.opacity(0.15)))
            .padding(.top, session.revealed ? 0 : 24)

        Text(situation.label)
            .font(.jakarta(session.revealed ? 26 : 32, weight: .bold))
            .foregroundColor(.warmWhite)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, session.revealed ? 4 : 24)
            .accessibilityAddTraits(.isHeader)

        if session.revealed {
            Text("What you could say")
                .font(.jakarta(13, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.6))
                .padding(.bottom, 2)
            ForEach(situation.lines) { line in
                SayThisLineRow(line: line, situationLabel: nil, lingoTerm: line.lingo.flatMap { lingoById[$0] }, store: store)
            }
            bigButton(session.index + 1 >= session.ids.count ? "Finish" : "Next", icon: "arrow.right") {
                if session.index + 1 >= session.ids.count {
                    session.finished = true
                } else {
                    session.index += 1
                    session.revealed = false
                }
            }
            .padding(.top, 12)
        } else {
            Text("Have a go in your head first.")
                .font(.jakarta(14, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.6))
                .padding(.bottom, 12)
            bigButton("Reveal", icon: "eye") { session.revealed = true }
        }
    }

    // MARK: The end

    @ViewBuilder
    private var finishedView: some View {
        VStack(spacing: 14) {
            Text("That's ten.")
                .font(.jakarta(30, weight: .bold))
                .foregroundColor(.warmWhite)
            Text("You've got lines for these now.")
                .font(.jakarta(16, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 20)

        // Nothing is marked right or wrong here, so there is no score to show
        // and no band to work out: she gets a strong-band line.
        HypeCard(hype: hype)
            .task { if hype == nil { hype = Hype.line(.strong, store: store) } }
            .padding(.bottom, 20)

        bigButton("Go again", icon: "arrow.clockwise", action: onRestart)

        Button(action: onFinishedExit) {
            Text("Back to all situations")
                .font(.jakarta(15, weight: .semiBold))
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func bigButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.jakarta(18, weight: .bold))
            }
            .foregroundColor(.warmWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.hotRose)
            .cornerRadius(Layout.buttonCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
