import SwiftUI

/// Called it: the slip, on the Lingo weekend screen.
///
/// Before kick-off it offers her three lines she might get to say during the
/// match, one near-certain, one likely, one long shot. She picks the ones she
/// fancies and goes and watches the game. During it, the goal push that was
/// going out anyway tells her when one of them landed.
///
/// **It never asks whether she said it**, here or anywhere else. The app knows
/// what happened on the pitch and that is the whole of it: no score, no streak,
/// no share sheet, and nothing to come back and settle. Not picking costs
/// nothing and leaves nothing behind.
///
/// Three states, in the order she meets them: the offer, the slip she has
/// already filled in, and afterwards the same lines with the ones that came up
/// marked. All the deciding is `LingoCalls`; this only draws it.
struct LingoCallsView: View {
    let calls: [LingoCall]
    @Bindable var store: MyTurnStore
    /// This weekend. Before kick-off it deals the offer; after the match it is
    /// what ties the stored slip to the game that has just been played.
    let context: MatchContext
    /// She confirmed. The caller sends it to the device row; the pick is
    /// already saved locally by then, so a failed upload costs her nothing.
    let onConfirm: ([LingoCall]) -> Void
    @Environment(AppState.self) private var appState

    /// Which lines she has tapped, before she confirms. View state on purpose:
    /// a slip half filled in is not worth persisting, and the confirmed one is.
    @State private var picked: Set<String> = []

    private var slip: MyTurnStore.MatchCalls? { store.matchCalls(for: context) }

    private var played: Bool {
        if case .after = context.phase { return true }
        return false
    }

    var body: some View {
        if let slip {
            filled(slip)
        } else if !played {
            offer
        }
    }

    // MARK: Before kick-off

    /// The three on offer, and one button.
    @ViewBuilder
    private var offer: some View {
        let offered = LingoCalls.offer(calls: calls, context: context)
        // Fewer than three is a legal slip (there is always a banker in it);
        // none at all means this fixture has nothing to offer, and the card
        // stays off the screen rather than apologising for itself.
        if !offered.isEmpty {
            card {
                heading("Called it", subtitle: subtitle(offered.count))

                ForEach(offered) { call in
                    row(call, picked: picked.contains(call.id), tappable: true)
                }

                Button {
                    confirm(offered)
                } label: {
                    Text("That's my slip")
                        .font(.jakarta(16, weight: .semiBold))
                        .foregroundColor(.warmWhite)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .background(picked.isEmpty ? Color.hotRose.opacity(0.35) : Color.hotRose)
                        .cornerRadius(Layout.buttonCornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(picked.isEmpty)
                .accessibilityLabel(picked.isEmpty
                                    ? "That's my slip. Pick a line first."
                                    : "That's my slip. Keeps \(picked.count == 1 ? "this line" : "these lines") for the match.")
            }
        }
    }

    /// "For Saturday. Things that might happen..." — the occasion reads as a
    /// weekday inside the week and as "the Fulham game" beyond it, so it has to
    /// sit behind "For", which is the one preposition both spellings take.
    private func subtitle(_ count: Int) -> String {
        let when = context.occasion(now: Date()).map { "For \($0). " } ?? ""
        let what = count == 1 ? "One thing that might happen" : "Things that might happen"
        return "\(when)\(what). Pick what you fancy saying."
    }

    private func confirm(_ offered: [LingoCall]) {
        guard let fixtureId = context.fixtureId else { return }
        let picks = offered.filter { picked.contains($0.id) }
        guard !picks.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            store.commitMatchCalls(fixtureId: fixtureId, fixtureKey: context.fixtureKey,
                                   pickedIds: picks.map(\.id))
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onConfirm(picks)
    }

    // MARK: The slip she filled in

    /// Her lines: waiting for the match, then the same lines with the ones that
    /// came up marked.
    ///
    /// Only the ones we know landed are marked. Nothing is ever marked as
    /// having missed: the push resolves against the feed's events while she is
    /// watching, and what the app can work out for itself afterwards is the
    /// full-time result and nothing else (`LingoCalls.outcomes(after:)`), so a
    /// cross here would be a claim the app cannot stand behind.
    @ViewBuilder
    private func filled(_ slip: MyTurnStore.MatchCalls) -> some View {
        let mine = picks(slip)
        if !mine.isEmpty {
            let landed = Set(LingoCalls.matched(stored: slip, fixtureId: slip.fixtureId,
                                                calls: mine,
                                                outcomes: LingoCalls.outcomes(after: context)).map(\.id))
            card {
                heading("Called it", subtitle: played
                        ? "What you called\(context.occasion(now: Date()).map { " for \($0)" } ?? "")."
                        : "You're watching for \(mine.count == 1 ? "this one" : "these").")

                ForEach(mine) { call in
                    row(call, picked: true, tappable: false, landed: landed.contains(call.id))
                }

                if !played {
                    Text("We'll tell you when one comes up.")
                        .font(.jakarta(14, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The calls she picked, in band order so the card reads the same way it
    /// did when she filled it in. A line whose id has since been unpublished
    /// simply drops off: the copy that has to survive without the bundle is the
    /// one on the device row, which carries its own text.
    private func picks(_ slip: MyTurnStore.MatchCalls) -> [LingoCall] {
        let ids = Set(slip.pickedIds)
        let order = Dictionary(uniqueKeysWithValues: LingoCalls.Band.allCases.enumerated().map { ($1.rawValue, $0) })
        return calls.filter { ids.contains($0.id) && LingoCalls.usable($0) }
            .sorted { (order[$0.band ?? ""] ?? 9, $0.id) < (order[$1.band ?? ""] ?? 9, $1.id) }
    }

    // MARK: Pieces

    /// One line, and how hard she is making it for herself.
    ///
    /// Modelled on `MyTurnOptionButton` and deliberately not it: that one is a
    /// quiz option, with a right answer, a wrong answer and nothing tappable
    /// after the first tap. Nothing here is right or wrong, and she can pick
    /// all three.
    @ViewBuilder
    private func row(_ call: LingoCall, picked isPicked: Bool, tappable: Bool,
                     landed: Bool = false) -> some View {
        let band = LingoCalls.Band(rawValue: call.band ?? "")
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let band {
                    Text(band.label.uppercased())
                        .font(.jakarta(10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.hotRose)
                }
                Spacer(minLength: 0)
                if landed {
                    Text("CAME UP")
                        .font(.jakarta(10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.hotRose)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.hotRose.opacity(0.18)))
                } else if isPicked, !played {
                    // Only while she is waiting. Afterwards every row on the
                    // card is one she picked, so a tick there reads as "this
                    // one happened" next to the badge that actually means it.
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.hotRose)
                        .accessibilityHidden(true)
                }
            }
            Text(appState.personalise(call.line))
                .font(.jakarta(16, weight: .medium))
                .foregroundColor(.textPrimaryOnCard)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPicked ? Color.hotRose.opacity(0.18) : Color.clear)
        .background(Color.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isPicked ? Color.hotRose : Color.clear, lineWidth: 1.5))
        .cornerRadius(12)
        .contentShape(Rectangle())

        if tappable {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if picked.contains(call.id) { picked.remove(call.id) } else { picked.insert(call.id) }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(band?.label ?? "A line"). \(appState.personalise(call.line))")
            .accessibilityValue(isPicked ? "On your slip" : "")
            .accessibilityHint(isPicked ? "Takes it off your slip" : "Puts it on your slip")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(band?.label ?? "A line"). \(appState.personalise(call.line))")
                .accessibilityValue(landed ? "Came up" : "")
        }
    }

    @ViewBuilder
    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.warmWhite)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.jakarta(14, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The same card the settle row and the commitment card are drawn in.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.warmWhite.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
            .stroke(Color.hotRose.opacity(0.35), lineWidth: 1))
        .cornerRadius(Layout.cardCornerRadius)
        .transition(.opacity)
    }
}
