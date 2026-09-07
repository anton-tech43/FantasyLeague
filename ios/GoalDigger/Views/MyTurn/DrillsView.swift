import SwiftUI

/// Module 4 — Drills. The repetition engine. Owns no content of its own:
/// Lines and Terms decks are built from Say This and Lingo, and the four
/// static decks (Kits, Badges, Nicknames, Players) come from drills.json.
///
/// Tap to flip, then Knew it / Didn't know it. Three buckets — new, learning,
/// known — no real spaced repetition in v1. Ten cards a session.
struct DrillsView: View {
    @Bindable var store: MyTurnStore
    @State private var content = MyTurnContentService.shared

    /// A resolved card the session can render, whichever deck it came from.
    struct Card: Identifiable, Hashable {
        let id: String
        let frontType: DrillFrontType
        let front: DrillFront
        let back: String
        /// Small caption under the front (the situation label on a Lines card).
        let hint: String?
    }

    private func cards(for deck: DrillDeck) -> [Card] {
        switch deck.source {
        case .saythis:
            return content.sayThis.situations.flatMap { s in
                s.lines.map { Card(id: $0.id, frontType: .text, front: .text(s.label), back: $0.text, hint: nil) }
            }
        case .lingo:
            return content.lingo.terms.map { Card(id: $0.id, frontType: .text, front: .text($0.term), back: $0.meaning, hint: nil) }
        case .staticCards:
            return (deck.cards ?? []).map { Card(id: $0.id, frontType: $0.frontType, front: $0.front, back: $0.back, hint: nil) }
        }
    }

    private var session: MyTurnStore.DrillSession? { store.drillSession }
    private var sessionDeck: DrillDeck? { session.flatMap { s in content.drills.decks.first { $0.id == s.deckId } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                if let session, let deck = sessionDeck {
                    if session.finished {
                        doneView(deck)
                    } else {
                        cardView(session, deck: deck)
                    }
                } else {
                    deckList
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: session?.index)
        .animation(.easeInOut(duration: 0.2), value: session?.finished)
    }

    // MARK: Deck list

    @ViewBuilder
    private var deckList: some View {
        MyTurnSectionLabel(text: "Pick a deck")
        ForEach(content.drills.decks) { deck in
            let all = cards(for: deck)
            if !all.isEmpty {
                let known = store.knownCount(deckId: deck.id)
                Button {
                    store.startDrill(deckId: deck.id, cardIds: all.map(\.id))
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    MyTurnRow(title: deck.label, subtitle: "\(known) of \(all.count) known") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.hotRose)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Card

    @ViewBuilder
    private func cardView(_ session: MyTurnStore.DrillSession, deck: DrillDeck) -> some View {
        let all = cards(for: deck)
        let byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if session.index < session.queue.count, let card = byId[session.queue[session.index]] {
            HStack {
                Text("\(deck.label) · \(min(session.done + 1, 10)) of 10")
                    .font(.sectionHeader).tracking(1)
                    .foregroundColor(.mutedText)
                Spacer()
                Button("Stop") { store.endDrill() }
                    .font(.jakarta(13, weight: .semiBold))
                    .foregroundColor(.hotRose)
            }

            Button {
                if !session.flipped {
                    store.flip()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.cardBackground)
                    if session.flipped {
                        Text(card.back)
                            .font(.jakarta(card.back.count > 60 ? 18 : 26, weight: .bold))
                            .foregroundColor(.textPrimaryOnCard)
                            .multilineTextAlignment(.center)
                            .padding(24)
                    } else {
                        cardFront(card)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.hotRose.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.flipped ? "Answer: \(card.back)" : "Card. Tap to see the answer")

            if !session.flipped {
                if session.done == 0 {
                    Text("Tap to see the answer")
                        .font(.jakarta(13, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 12) {
                    gradeButton("Didn't know it", filled: false) { store.grade(knewIt: false) }
                    gradeButton("Knew it", filled: true) { store.grade(knewIt: true) }
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func cardFront(_ card: Card) -> some View {
        switch card.frontType {
        case .image:
            if let path = card.front.string, let url = MyTurnContentService.imageURL(path),
               let ui = UIImage(contentsOfFile: url.path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .padding(24)
            } else {
                // Remote content referencing an image the app does not ship
                // with: fall back to a question mark rather than a blank card.
                Image(systemName: "questionmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.textSecondaryOnCard)
            }
        case .kit:
            if let kit = card.front.kit {
                KitView(spec: kit)
                    .frame(width: 180, height: 200)
                    .padding(24)
            }
        case .text:
            Text(card.front.string ?? "")
                .font(.jakarta(26, weight: .bold))
                .foregroundColor(.textPrimaryOnCard)
                .multilineTextAlignment(.center)
                .padding(24)
        }
    }

    private func gradeButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(filled ? .warmWhite : .hotRose)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(filled ? Color.hotRose : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius).stroke(Color.hotRose, lineWidth: 1))
                .cornerRadius(Layout.buttonCornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: Done

    @ViewBuilder
    private func doneView(_ deck: DrillDeck) -> some View {
        let all = cards(for: deck)
        Text("10 done.")
            .font(.jakarta(30, weight: .bold))
            .foregroundColor(.warmWhite)
        Text("\(store.knownCount(deckId: deck.id)) of \(all.count) known in \(deck.label).")
            .font(.jakarta(15, weight: .regular))
            .foregroundColor(.warmWhite.opacity(0.8))

        Button {
            store.startDrill(deckId: deck.id, cardIds: all.map(\.id))
        } label: {
            Text("Go again")
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(.warmWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.hotRose)
                .cornerRadius(Layout.buttonCornerRadius)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)

        Button {
            store.endDrill()
        } label: {
            Text("Pick a deck")
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius).stroke(Color.hotRose, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
