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
///
/// Only the offer is a full screen. It is the one state that asks her for
/// something, and it is the one Anton was looking at when he said "den här
/// sidan vill man inte ens vara på" — so it gets the whole viewport and every
/// other thing in Lingo goes below the fold. The two states she only reads are
/// still cards, because a card she has already filled in has nothing to ask.
struct LingoCallsView: View {
    let calls: [LingoCall]
    @Bindable var store: MyTurnStore
    /// This weekend. Before kick-off it deals the offer; after the match it is
    /// what ties the stored slip to the game that has just been played.
    let context: MatchContext
    /// The offer filling the Lingo content, or the compact filled card on the
    /// landing. `LingoView` decides which; this only draws it.
    var presentation: Presentation = .inline
    /// She confirmed. The caller sends it to the device row; the pick is
    /// already saved locally by then, so a failed upload costs her nothing.
    let onConfirm: ([LingoCall]) -> Void
    @Environment(AppState.self) private var appState

    enum Presentation { case takeover, inline }

    /// The cover comes first — the mockup's "Get ready for the game" and its
    /// arrow — then the lines. Reset when the fixture changes.
    @State private var showedCover = LingoCallsView.debugSkipCover
    /// The cover arrow's slow nudge, so it reads as "go" rather than décor.
    @State private var arrowNudge = false

    /// Which lines she has said yes to, before the slip commits, and which one
    /// she is being asked about. Both view state on purpose: a half-walked slip
    /// is not worth persisting, the module views stay mounted so it survives a
    /// tab switch, and a relaunch starting again at the first line is correct.
    @State private var picked: Set<String> = []
    @State private var index = LingoCallsView.startIndex
    @Environment(\.dynamicTypeSize) private var typeSize

    private var slip: MyTurnStore.MatchCalls? { store.matchCalls(for: context) }

    private var played: Bool {
        if case .after = context.phase { return true }
        return false
    }

    var body: some View {
        if let slip {
            // She has acted — the compact "watching for these" card.
            filled(slip)
        } else if !played, presentation == .takeover {
            offer
        }
    }

    // MARK: Before kick-off

    /// One line, yes or no, then the next one — filling the screen.
    ///
    /// Three cards at once was three decisions at once with a button under
    /// them, on a screen Anton read as "för mycket som händer". One card is one
    /// decision, and the last yes or no IS the confirmation — there is no
    /// separate "That's my slip", because a button that only ever means "I've
    /// finished answering" is a fourth thing to understand.
    ///
    /// The short version of that card was still wrong, and the diagnosis was
    /// weight rather than shape: the line she might say sat in a white rounded
    /// box, the glossary row under it sat in an identical white rounded box,
    /// and the only saturated surface on the screen belonged to the hero, so
    /// the eye landed on none of them. Full height fixes it by having nothing
    /// to compete with — the situation gets a headline, the line gets a size
    /// worth reading, and the hero and the 158 words are one scroll away
    /// rather than in the same glance.
    @ViewBuilder
    private var offer: some View {
        // `offer` recomputes on every body evaluation and a content refresh can
        // shrink it under her, so the index is read safely and never trusted.
        // Fewer than three is a legal slip (there is always a banker in it).
        let offered = LingoCalls.offer(calls: calls, context: context)
        // The card fills the Lingo content height. `containerRelativeFrame`
        // reads the surrounding scroll view's visible region, which a
        // GeometryReader cannot do from inside a scroll that sizes to content
        // (it collapses to nothing there).
        Group {
            if !showedCover {
                coverCard
            } else if let call = offered[safe: index] {
                offerScreen(call, of: offered)
            }
        }
        .containerRelativeFrame(.vertical, alignment: .top)
        // A different fixture is a different slip, and this view stays mounted
        // across one arriving.
        .onChange(of: context.fixtureKey) { _, _ in
            index = 0
            picked = []
            showedCover = false
        }
    }

    /// The mockup's cover: the one bold line and the big arrow that starts the
    /// slip. Same League Spartan Black the feed's immersive card leads with, so
    /// coming into Lingo on a match week feels like the feed does.
    private var coverCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showedCover = true }
        } label: {
            ZStack {
                // The big blocky arrow from the sketch, low and to the right,
                // overlapping the level of the second line. Drawn rather than a
                // system symbol: the sketch's is a clean rectangle tail and a
                // triangle head with sharp edges, not the tapered rounded glyph.
                BlockArrow()
                    .fill(Color.hotRose)
                    .frame(width: 230, height: 150)
                    .offset(x: arrowNudge ? 12 : 0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                               value: arrowNudge)
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.top, 150)
                    .onAppear { arrowNudge = true }
                // Two lines — "Get ready for" / "the game" — set by hand so the
                // first fits one line and the two stack tight, the closeness the
                // feed's immersive headline has and a wrapping Text loses.
                VStack(alignment: .leading, spacing: -6) {
                    Text("Get ready for")
                    Text("the game")
                }
                .font(.custom("LeagueSpartan-Black", size: 46))
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(.textPrimaryOnCard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Get ready for the game. Start.")
    }

    /// The offer, drawn on the brightest surface in the app.
    ///
    /// Blush and not rose on purpose: the hero directly below is `hotRose`, and
    /// two saturated pink blocks in a column are two things shouting. A full
    /// bleed of the light card colour against the mauve background is the most
    /// primary this screen can be without taking the hero's colour off it, and
    /// it leaves rose free to mean exactly two things here — the line she would
    /// say, and the button that puts it on her slip.
    private func offerScreen(_ call: LingoCall, of offered: [LingoCall]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The slip she is building, as pips rather than "1 of 3" — the
            // filled ones are the picks so far, the wide one is this line.
            pips(of: offered.count)

            Spacer(minLength: 28).frame(maxHeight: 88)

            VStack(alignment: .leading, spacing: 16) {
                // The moment, in the same League Spartan the cover leads with,
                // so answering reads as the next beat of one screen and not a
                // new one.
                Text(moment(call))
                    .font(.calledItHeadline)
                    .tracking(-1)
                    .foregroundColor(.textPrimaryOnCard)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\u{201C}\(appState.personalise(call.line))\u{201D}")
                    .font(.jakarta(22, weight: .semiBold))
                    .foregroundColor(.hotRose)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let cue = call.cue {
                    Text(appState.personalise(cue))
                        .font(.jakarta(15, weight: .regular))
                        .foregroundColor(.textSecondaryOnCard)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .dynamicTypeSize(...Self.displayCap)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(moment(call)). \(appState.personalise(call.line))")

            Spacer(minLength: 28)

            answerButtons(call, of: offered)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The same rounded blush card as the cover, so the flow is one surface.
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        // Each line arrives from the right, the way the cover's arrow points.
        .id(call.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity))
    }

    /// The slip as a row of pips: one per offered line, filled up to and
    /// including the one she is on, the current one widened.
    private func pips(of count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Color.hotRose : Color.hotRose.opacity(0.18))
                    .frame(width: i == index ? 26 : 14, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: index)
        .accessibilityLabel("Line \(index + 1) of \(count)")
    }

    /// How far the display type scales, and no further. It starts at 34 and 25
    /// points, so at `accessibility2` it is already bigger than body text is at
    /// the largest setting — past that it stops being a headline and becomes
    /// three words per screen. The cap is on the display type only: the cue,
    /// the buttons and every other state scale the whole way.
    private static let displayCap = DynamicTypeSize.accessibility2

    /// Side by side until the text is big enough that two words on one row
    /// start truncating, then one above the other. Nothing here may shrink or
    /// clip: these two are the only way off this screen.
    @ViewBuilder
    private func answerButtons(_ call: LingoCall, of offered: [LingoCall]) -> some View {
        let yes = Button {
            answer(call, yes: true, of: offered)
        } label: {
            answerLabel("Yes", filled: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Yes. Puts this line on your slip.")

        let no = Button {
            answer(call, yes: false, of: offered)
        } label: {
            answerLabel("No", filled: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No. Leaves this one off.")

        if typeSize >= .accessibility2 {
            VStack(spacing: 12) { yes; no }
        } else {
            HStack(spacing: 12) { yes; no }
        }
    }

    /// The promise, in the state where it is still ahead of her. It is off the
    /// offer at Anton's word — the screen that asks her a question carries the
    /// question and nothing else — so the first time she reads it is on the
    /// slip she has just filled in, and the wording must not move after that.
    private static let promise = "We'll tell you the moment one comes up."

    /// "For Saturday" — the occasion reads as a weekday inside the week and as
    /// "the Fulham game" beyond it, so it has to sit behind "For", which is the
    /// one preposition both spellings take.
    private var when: String {
        context.occasion(now: Date()).map { "For \($0). " } ?? ""
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
            .font(.jakarta(18, weight: .bold))
            .foregroundColor(filled ? .warmWhite : .hotRose)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.vertical, 4)
            .background(filled ? Color.hotRose : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius)
                .stroke(filled ? Color.clear : Color.hotRose, lineWidth: 1.5))
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
                    heading("Get in the game", subtitle: "\(when)None of those took your fancy. There'll be three more for the next one.")
                }
            }
        } else {
            let landed = Set(LingoCalls.matched(stored: slip, fixtureId: slip.fixtureId,
                                                calls: mine,
                                                outcomes: LingoCalls.outcomes(after: context)).map(\.id))
            card {
                // The one place the promise is made, and afterwards the one
                // place it is answered. Both read back what she picked; neither
                // asks her whether she said it.
                heading("Get in the game", subtitle: played
                        ? "What you called\(context.occasion(now: Date()).map { " for \($0)" } ?? "")."
                        : "\(when)\(Self.promise)")

                ForEach(mine) { call in
                    row(call, landed: landed.contains(call.id))
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

    /// One line she picked: the moment it belongs to and the words. Never
    /// tappable, and only ever drawn on a slip she has already filled in, so
    /// every row here is one of hers.
    ///
    /// No band label. "NEAR CERTAIN" over a line she has already chosen is a
    /// word about how the offer was built, not about her afternoon, and it was
    /// the loudest thing on the row.
    private func row(_ call: LingoCall, landed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // When she gets to say it, above the line rather than under it:
                // the moment is what she picked, and the words are what she
                // gets for picking it.
                Text(moment(call))
                    .font(.jakarta(13, weight: .semiBold))
                    .foregroundColor(.textSecondaryOnCard)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if landed {
                    Text("CAME UP")
                        .font(.jakarta(10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.hotRose)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.hotRose.opacity(0.18)))
                } else if !played {
                    // Only while she is waiting. Afterwards every row on the
                    // card is one she picked, so a tick there reads as "this
                    // one happened" next to the badge that actually means it.
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.hotRose)
                        .accessibilityHidden(true)
                }
            }
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
        .background(Color.hotRose.opacity(0.18))
        .background(Color.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.hotRose, lineWidth: 1.5))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(moment(call)). \(appState.personalise(call.line))")
        .accessibilityValue(landed ? "Came up" : "")
    }

    @ViewBuilder
    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.textPrimaryOnCard)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.jakarta(14, weight: .regular))
                .foregroundColor(.textSecondaryOnCard)
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
    /// `-gdLingoCallsStart` opens straight on the first yes/no line, past the
    /// cover, for a screenshot of a card simctl cannot tap to.
    private static var debugSkipCover: Bool {
        ProcessInfo.processInfo.arguments.contains("-gdLingoCallsStart")
    }
    #else
    private static let startIndex = 0
    private static let debugSkipCover = false
    #endif

    /// The compact card she comes back to — the same blush surface as the cover
    /// and the yes/no cards, so the whole flow is one family rather than a dark
    /// box tacked under the landing.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .transition(.opacity)
    }
}

/// The block arrow on the Called it cover: a rectangle tail into a triangle
/// head, sharp-edged, the way Anton's sketch draws it rather than the tapered,
/// rounded system `arrowshape.right.fill`.
private struct BlockArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let shaftTop = h * 0.30
        let shaftBottom = h * 0.70
        let headStart = w * 0.46   // the triangle head takes the right ~54%
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: shaftTop))
        p.addLine(to: CGPoint(x: rect.minX + headStart, y: shaftTop))
        p.addLine(to: CGPoint(x: rect.minX + headStart, y: rect.minY))       // head top
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))                    // point
        p.addLine(to: CGPoint(x: rect.minX + headStart, y: rect.maxY))       // head bottom
        p.addLine(to: CGPoint(x: rect.minX + headStart, y: shaftBottom))
        p.addLine(to: CGPoint(x: rect.minX, y: shaftBottom))
        p.closeSubpath()
        return p
    }
}
