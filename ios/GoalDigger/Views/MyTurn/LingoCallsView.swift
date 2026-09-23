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

    /// Which lines she has said yes to, before the slip commits, and which one
    /// she is being asked about. Both view state on purpose: a half-walked slip
    /// is not worth persisting, the module views stay mounted so it survives a
    /// tab switch, and a relaunch starting again at the first line is correct.
    @State private var picked: Set<String> = []
    @State private var index = LingoCallsView.startIndex

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

    /// One line, yes or no, then the next one.
    ///
    /// Three cards at once was three decisions at once with a button under
    /// them, on a screen Anton read as "för mycket som händer". One card is one
    /// decision, and the last yes or no IS the confirmation — there is no
    /// separate "That's my slip", because a button that only ever means "I've
    /// finished answering" is a fourth thing to understand.
    @ViewBuilder
    private var offer: some View {
        let offered = LingoCalls.offer(calls: calls, context: context)
        // `offer` recomputes on every body evaluation and a content refresh can
        // shrink it under her, so the index is read safely and never trusted.
        // Fewer than three is a legal slip (there is always a banker in it);
        // none at all means this fixture has nothing to offer, and the card
        // stays off the screen rather than apologising for itself.
        if let call = offered[safe: index] {
            card {
                heading("Called it", subtitle: offerSubtitle)

                HStack(spacing: 8) {
                    Text("\(index + 1) of \(offered.count)")
                        .font(.jakarta(13, weight: .semiBold))
                        .foregroundColor(.warmWhite.opacity(0.6))
                        .accessibilityLabel("Line \(index + 1) of \(offered.count)")
                    Spacer(minLength: 0)
                }

                row(call, picked: false)

                HStack(spacing: 10) {
                    Button {
                        answer(call, yes: true, of: offered)
                    } label: {
                        answerLabel("Yes", filled: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Yes. Puts this line on your slip.")

                    Button {
                        answer(call, yes: false, of: offered)
                    } label: {
                        answerLabel("No", filled: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("No. Leaves this one off.")
                }
            }
            // A floor, not a height: the card is the top of the screen now and
            // the hero sits directly under it, so a line that wraps to two
            // where the last one wrapped to three would move the hero under
            // her thumb between one answer and the next.
            .frame(minHeight: Self.slipMinHeight, alignment: .top)
            // A different fixture is a different slip, and this view stays
            // mounted across one arriving.
            .onChange(of: context.fixtureKey) { _, _ in
                index = 0
                picked = []
            }
        }
    }

    /// The tallest the offer card gets at the default text size: a heading over
    /// two lines, a moment over two and a fifty-character line over three. Only
    /// a floor, so a bigger text size still grows past it.
    private static let slipMinHeight: CGFloat = 300

    /// The promise, word for word in both states: it is what she is agreeing to
    /// while she picks, and it must not change wording once she has.
    private static let promise = "We'll tell you the moment one comes up."

    /// "For Saturday" — the occasion reads as a weekday inside the week and as
    /// "the Fulham game" beyond it, so it has to sit behind "For", which is the
    /// one preposition both spellings take.
    private var when: String {
        context.occasion(now: Date()).map { "For \($0). " } ?? ""
    }

    private var offerSubtitle: String {
        "\(when)Would you say it? \(Self.promise)"
    }

    /// Yes puts it on the slip, no does not, and both move her on. Past the
    /// last one the slip commits itself — including the empty one, because a
    /// slip she walked and fancied none of has to be remembered as walked or
    /// the same three come back on every open, which is nagging.
    private func answer(_ call: LingoCall, yes: Bool, of offered: [LingoCall]) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if yes { picked.insert(call.id) }
            index += 1
        }
        UIImpactFeedbackGenerator(style: yes ? .medium : .light).impactOccurred()
        if index >= offered.count { confirm(offered) }
    }

    private func answerLabel(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.jakarta(16, weight: .semiBold))
            .foregroundColor(filled ? .warmWhite : .hotRose)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(filled ? Color.hotRose : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius)
                .stroke(filled ? Color.clear : Color.hotRose, lineWidth: 1))
            .cornerRadius(Layout.buttonCornerRadius)
            .contentShape(Rectangle())
    }

    private func confirm(_ offered: [LingoCall]) {
        guard let fixtureId = context.fixtureId else { return }
        let picks = offered.filter { picked.contains($0.id) }
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
        if mine.isEmpty {
            // She walked the slip and fancied none of it. Stored, so the same
            // three do not come back on every open, and said out loud, so the
            // card going quiet does not read as one that broke. No second ask
            // and nothing to undo: not picking costs nothing.
            if !played {
                card {
                    heading("Called it", subtitle: "\(when)None of those took your fancy. There'll be three more for the next one.")
                }
            }
        } else {
            let landed = Set(LingoCalls.matched(stored: slip, fixtureId: slip.fixtureId,
                                                calls: mine,
                                                outcomes: LingoCalls.outcomes(after: context)).map(\.id))
            card {
                // The same promise, in the same words, either side of the last
                // yes: the card she reads back has to be the card she agreed to.
                heading("Called it", subtitle: played
                        ? "What you called\(context.occasion(now: Date()).map { " for \($0)" } ?? "")."
                        : "\(when)\(Self.promise)")

                ForEach(mine) { call in
                    row(call, picked: true, landed: landed.contains(call.id))
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

    /// When she gets to say it. Hand-written where the content has bothered,
    /// and read off the trigger where it has not — `moment` covers all 59, so
    /// no card ever draws a blank line where the moment should be.
    private func moment(_ call: LingoCall) -> String {
        call.situation ?? LingoCalls.moment(call.trigger)
    }

    /// One line: the moment it belongs to, the words, and how hard she is
    /// making it for herself. Never tappable — the row is what she is being
    /// asked about, and the two buttons under it are the answer.
    private func row(_ call: LingoCall, picked isPicked: Bool,
                     landed: Bool = false) -> some View {
        let band = LingoCalls.Band(rawValue: call.band ?? "")
        return VStack(alignment: .leading, spacing: 6) {
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
            // When she gets to say it, above the line rather than under it:
            // the moment is what she is picking, and the words are what she
            // gets for picking it.
            Text(moment(call))
                .font(.jakarta(13, weight: .semiBold))
                .foregroundColor(.textSecondaryOnCard)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text("\u{201C}\(appState.personalise(call.line))\u{201D}")
                .font(.jakarta(16, weight: .medium))
                .foregroundColor(.textPrimaryOnCard)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            // Why it is worth calling, where the content has written one.
            if let cue = call.cue {
                Text(appState.personalise(cue))
                    .font(.jakarta(13, weight: .regular))
                    .foregroundColor(.textSecondaryOnCard)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPicked ? Color.hotRose.opacity(0.18) : Color.clear)
        .background(Color.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isPicked ? Color.hotRose : Color.clear, lineWidth: 1.5))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(band?.label ?? "A line"). \(moment(call)). \(appState.personalise(call.line))")
        .accessibilityValue(landed ? "Came up" : "")
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

    #if DEBUG
    /// `-gdLingoCallsIndex 2` starts the slip on the third line, because simctl
    /// cannot tap through the first two. Clamped by the safe subscript, so a
    /// number past the end simply draws no card.
    private static var startIndex: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-gdLingoCallsIndex"), i + 1 < args.count else { return 0 }
        return Int(args[i + 1]) ?? 0
    }
    #else
    private static let startIndex = 0
    #endif

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
