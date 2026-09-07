import SwiftUI

/// The toolbox tab. One segmented control, four modules, exactly one visible.
///
/// All four module views stay mounted (opacity-switched) so scroll position,
/// search text and an open situation survive a switch without any plumbing;
/// the durable state lives in `MyTurnStore` so it also survives a relaunch.
struct MyTurnView: View {
    @State private var store = MyTurnStore.shared
    @State private var content = MyTurnContentService.shared
    @Environment(AppState.self) var appState

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                segmentedControl
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ZStack {
                    SayThisView(content: content.sayThis, store: store)
                        .opacity(store.lastModule == .sayThis ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .sayThis)
                    LingoView(content: content.lingo, store: store)
                        .opacity(store.lastModule == .lingo ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .lingo)
                    QuizView(content: content.quiz, store: store, clubId: appState.selectedTeam?.rawValue)
                        .opacity(store.lastModule == .quiz ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .quiz)
                    DrillsView(store: store)
                        .opacity(store.lastModule == .drills ? 1 : 0)
                        .allowsHitTesting(store.lastModule == .drills)
                }
            }
        }
        .navigationTitle("My Turn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #if DEBUG
        .onAppear(perform: applyLaunchArguments)
        #endif
    }

    #if DEBUG
    /// Screenshot harness, see MainTabView. `-gdMyTurnModule quiz`,
    /// `-gdMyTurnSituation sideways`, `-gdMyTurnPack legends`,
    /// `-gdMyTurnDeck kits`, `-gdLingoQuery offside`.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let m = value("-gdMyTurnModule").flatMap(MyTurnModule.init(rawValue:)) { store.lastModule = m }
        if let s = value("-gdMyTurnSituation") { store.sayThisSituationId = s }
        if let q = value("-gdLingoQuery") { store.lingoQuery = q }
        if let p = value("-gdMyTurnPack"), let pack = content.quiz.packs.first(where: { $0.id == p }) {
            store.startRound(pack: pack)
        }
        if let d = value("-gdMyTurnDeck"), let deck = content.drills.decks.first(where: { $0.id == d }) {
            let ids: [String]
            switch deck.source {
            case .saythis: ids = content.sayThis.situations.flatMap { $0.lines.map(\.id) }
            case .lingo: ids = content.lingo.terms.map(\.id)
            case .staticCards: ids = (deck.cards ?? []).map(\.id)
            }
            store.startDrill(deckId: deck.id, cardIds: ids)
        }
    }
    #endif

    /// Four fixed segments, full width, no horizontal scroll. Same visual
    /// language as the team page's Info / Calendar / Table control: the
    /// selected segment is a rose pill, the rest are recessed text.
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(MyTurnModule.allCases) { module in
                Button {
                    withAnimation(.spring(duration: 0.25)) { store.lastModule = module }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    // "Say This" is the longest label. At the largest
                    // accessibility sizes it becomes "Lines" rather than
                    // truncating or scrolling.
                    ViewThatFits(in: .horizontal) {
                        Text(module.label)
                        Text(module.shortLabel)
                    }
                    .font(.jakarta(15, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(store.lastModule == module ? Color.hotRose : Color.clear)
                    .foregroundColor(store.lastModule == module ? .warmWhite : .warmWhite.opacity(0.6))
                    .cornerRadius(12)
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
