import SwiftUI

/// The toolbox tab. One segmented control, three modules, exactly one visible.
///
/// All four module views stay mounted (opacity-switched) so scroll position,
/// search text and an open situation survive a switch without any plumbing;
/// the durable state lives in `MyTurnStore` so it also survives a relaunch.
struct MyTurnView: View {
    @State private var store = MyTurnStore.shared
    @State private var content = MyTurnContentService.shared
    @State private var live = LiveClubPackService.shared
    @State private var squad = LiveSquadService.shared
    @Environment(AppState.self) var appState
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                segmentedControl
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ZStack {
                    SayThisView(content: content.sayThis, lingo: content.lingo, store: store)
                        .opacity(store.lastModule == .sayThis ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .sayThis)
                    LingoView(content: content.lingo, sayThis: content.sayThis, store: store,
                              team: appState.selectedTeam, page: live.page)
                        .opacity(store.lastModule == .lingo ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .lingo)
                    QuizView(content: content.quiz, store: store, clubId: appState.selectedTeam?.rawValue,
                             livePack: live.pack, squadPack: squad.pack, leaguePack: live.leaguePack)
                        .opacity(store.lastModule == .quiz ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .quiz)

                    // Above the module content, so four in a row is seen
                    // wherever she is when it happens.
                    HypeStreakOverlay(store: store)
                }
                // Rebuild every module when the store is wiped — see
                // MyTurnStore.resetTick for what would otherwise survive it.
                .id(store.resetTick)
            }
        }
        .navigationTitle("My Turn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: appState.selectedTeam?.rawValue) {
            let personalise = appState.personalise
            async let club: Void = live.refresh(team: appState.selectedTeam, personalise: personalise)
            async let squadRefresh: Void = squad.refresh(team: appState.selectedTeam, personalise: personalise)
            _ = await (club, squadRefresh)
            #if DEBUG
            applyLivePackArguments()
            #endif
        }
        #if DEBUG
        .onAppear(perform: applyLaunchArguments)
        #endif
    }

    #if DEBUG
    /// Screenshot harness, see MainTabView. `-gdMyTurnModule quiz`,
    /// `-gdMyTurnSituation sideways`, `-gdMyTurnPack legends`,
    /// `-gdLingoQuery offside`, `-gdLingoExpand offside`. Everything else Lingo
    /// takes is handled in `LingoView.applyLingoArguments`.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        // `-gdResetMyTurn` wipes the persisted My Turn state first, so a
        // round from an earlier launch cannot shadow the screen being checked.
        if args.contains("-gdResetMyTurn") { store.clearAll() }
        if let m = value("-gdMyTurnModule").flatMap(MyTurnModule.init(rawValue:)) { store.lastModule = m }
        if let s = value("-gdMyTurnSituation") { store.sayThisSituationId = s }
        if let q = value("-gdLingoQuery") { store.lingoQuery = q }
        if let e = value("-gdLingoExpand") { store.lingoExpandedId = e }
        if let p = value("-gdMyTurnPack"), let pack = content.quiz.packs.first(where: { $0.id == p }) {
            store.startRound(pack: pack)
            applyQuizAnswerArgument(pack: pack)
        }
    }

    /// `-gdMyTurnPack live-club|live-squad|live-league` waits for the pack that
    /// is built on the device; `-gdQuizAnswer N` answers the first question with
    /// option N so the feedback renders, `-gdQuizAutoCorrect N` answers the
    /// first N correctly, `-gdQuizFinish N` plays a whole round to a score of N.
    private func applyLivePackArguments() {
        let args = ProcessInfo.processInfo.arguments
        let built = [live.pack, squad.pack, live.leaguePack].compactMap { $0 }
        guard let i = args.firstIndex(of: "-gdMyTurnPack"), i + 1 < args.count,
              let pack = built.first(where: { $0.id == args[i + 1] }), store.quizRound == nil else { return }
        // `-gdMyTurnQuestion <id>` starts a one-question round, for screenshots
        // of a specific question (the photo ones).
        if let j = args.firstIndex(of: "-gdMyTurnQuestion"), j + 1 < args.count {
            store.startRetryRound(pack: pack, missedIds: [args[j + 1]])
        } else {
            store.startRound(pack: pack)
        }
        applyQuizAnswerArgument(pack: pack)
    }

    private func applyQuizAnswerArgument(pack: QuizPack) {
        let args = ProcessInfo.processInfo.arguments
        func intValue(_ flag: String) -> Int? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return Int(args[i + 1])
        }
        if let a = intValue("-gdQuizAnswer"), let round = store.quizRound,
           let q = pack.questions.first(where: { $0.id == round.questionIds[0] }) {
            store.answer(a, correct: a == q.answer, questionId: q.id)
        }
        // `-gdQuizAutoCorrect 3` answers the first three correctly and stops on
        // the third, which is where the streak card appears; `-gdQuizFinish 8`
        // plays the whole round to a score of eight, for the result card.
        // Neither is reachable with simctl, which cannot tap.
        let byId = Dictionary(pack.questions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func play(_ count: Int, correct: (Int) -> Bool, advanceLast: Bool) {
            guard let ids = store.quizRound?.questionIds else { return }
            for i in 0..<min(count, ids.count) {
                guard let q = byId[ids[i]] else { continue }
                let right = correct(i)
                let option = right ? q.answer : (q.answer + 1) % max(q.options.count, 1)
                store.answer(option, correct: right, questionId: q.id)
                if advanceLast || i < count - 1 { store.nextQuestion() }
            }
        }
        if let n = intValue("-gdQuizAutoCorrect") {
            play(n, correct: { _ in true }, advanceLast: false)
        } else if let target = intValue("-gdQuizFinish"), let total = store.quizRound?.questionIds.count {
            play(total, correct: { $0 < target }, advanceLast: true)
        }
    }
    #endif

    /// Three fixed segments, full width, no horizontal scroll. Same visual
    /// language as the team page's Info / Calendar / Table control: the
    /// selected segment is a rose pill, the rest are recessed text.
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(MyTurnModule.allCases) { module in
                Button {
                    withAnimation(.spring(duration: 0.25)) { store.lastModule = module }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    // Three segments share the width, so every label needs a
                    // way down at the largest accessibility sizes: "Say This"
                    // becomes "Lines", and any of the three will shrink to 60%
                    // before it truncates. The pill is clipped so a label that
                    // still cannot fit does not run over its neighbour.
                    // ViewThatFits does not help here — inside an HStack of
                    // three flexible children it is proposed the ideal width
                    // and always takes the first rung.
                    Text(typeSize.isAccessibilitySize ? module.shortLabel : module.label)
                        .font(.jakarta(15, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(store.lastModule == module ? Color.hotRose : Color.clear)
                        .foregroundColor(store.lastModule == module ? .warmWhite : .warmWhite.opacity(0.6))
                        .cornerRadius(12)
                        .clipped()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(module.label)
                .accessibilityAddTraits(store.lastModule == module ? .isSelected : [])
            }
        }
    }
}

// MARK: - Shared bits

/// Uppercase rose section label used across the four modules.
struct MyTurnSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.sectionHeader)
            .tracking(1)
            .foregroundColor(.mutedText)
            .padding(.leading, 4)
    }
}

/// Blush card row with a chevron, for the list levels.
struct MyTurnRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.textPrimaryOnCard)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.jakarta(13, weight: .regular))
                        .foregroundColor(.textSecondaryOnCard)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .contentShape(Rectangle())
    }
}

/// One multiple-choice option, as the quiz and the Overheard round both draw
/// it: blush card, rose tint and a tick on the right answer once she has
/// picked, a red cross on hers when it was not, and nothing tappable after.
///
/// Shared because the two modules ask the same question in the same shape, and
/// a tick that looks different in one of them reads as a different meaning.
struct MyTurnOptionButton: View {
    let text: String
    let index: Int
    let answer: Int
    /// The option she picked, if any. Non-nil is the answered state.
    let selected: Int?
    let onPick: (Int) -> Void

    var body: some View {
        let answered = selected != nil
        let isCorrect = index == answer
        let isPicked = index == selected
        let background: Color = {
            guard answered else { return .cardBackground }
            if isCorrect { return Color.hotRose.opacity(0.18) }
            if isPicked { return Color.red.opacity(0.10) }
            return .cardBackground
        }()
        return Button {
            guard !answered else { return }
            onPick(index)
            UIImpactFeedbackGenerator(style: isCorrect ? .medium : .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Text(text)
                    .font(.jakarta(16, weight: .medium))
                    .foregroundColor(.textPrimaryOnCard)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if answered && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.hotRose)
                        .accessibilityHidden(true)
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7))
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(answered && isCorrect ? Color.hotRose : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(answered)
        // The tick and the cross are the whole answer for a sighted reader, so
        // VoiceOver needs them said rather than drawn. As a value, not a label:
        // the option's own text stays the label, and the state is what changed.
        .accessibilityValue(answered ? (isCorrect ? "Correct answer" : (isPicked ? "Your answer, wrong" : "")) : "")
    }
}

/// A popup over a module: a scrim that swallows taps, a verdict she cannot
/// miss, and exactly one way out.
///
/// The reveal used to be appended under the options in the same scrolling
/// column, four hundred points down, with nothing scrolling it into view — so
/// on a real card the answer, the line she can say and the Next button all
/// started at or below the fold. Above everything is the only place a reveal
/// can be.
///
/// Not a `.sheet`: a sheet is swipe-dismissible, and a swipe would leave her
/// on an answered card with dead options and no way forward. The scrim
/// deliberately does nothing when tapped, and the escape gesture does what the
/// button does rather than closing anything on its own.
///
/// Shared because the quiz has the identical problem. Nothing about it is
/// Lingo's.
struct MyTurnPopup<Content: View>: View {
    /// "Right." / "Not that one." — and where VoiceOver lands when it opens,
    /// because the popup arrives without her having moved.
    let verdict: String
    var verdictTint: Color = .hotRose
    /// The one way out, and what its button says.
    let exitLabel: String
    let exit: () -> Void
    @ViewBuilder var content: () -> Content
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        // Top-aligned, not centred: the reveal comes up where she was just
        // looking — the line and the options near the top of the round — rather
        // than dropping into the middle of the screen (Anton, "den bör starta
        // där frågan kommer"). The scrim still covers everything.
        ZStack(alignment: .top) {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                // Swallows the tap rather than passing it to the options
                // underneath, which are answered and must stay that way.
                .contentShape(Rectangle())
                .onTapGesture { }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(verdict)
                    .font(.jakarta(17, weight: .bold))
                    .foregroundColor(verdictTint)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focused)

                content()

                Button {
                    exit()
                } label: {
                    Text(exitLabel)
                        .font(.jakarta(16, weight: .semiBold))
                        .foregroundColor(.warmWhite)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .background(Color.hotRose)
                        .cornerRadius(Layout.buttonCornerRadius)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel(exitLabel)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Opaque, over the scrim: the same card the modules draw, with
            // something solid behind it so nothing reads through.
            .background(Color.warmWhite.opacity(0.08))
            .background(Color.appBackground)
            .overlay(RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.45), lineWidth: 1))
            .cornerRadius(Layout.cardCornerRadius)
            .padding(.horizontal, Layout.screenPadding)
            .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
            // Clears the "My Turn" title and the module tabs so the card lands
            // roughly where the round's line and question sit, on any device
            // (the offset is below the chrome, not a fixed screen position).
            .padding(.top, 96)
        }
        // Everything behind it is untouchable to VoiceOver as well as to her
        // thumb, and the escape gesture is the button rather than a way round
        // it.
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, exit)
        .onAppear { focused = true }
    }
}

struct MyTurnEmptyText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.jakarta(15, weight: .regular))
            .foregroundColor(.warmWhite.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
    }
}
