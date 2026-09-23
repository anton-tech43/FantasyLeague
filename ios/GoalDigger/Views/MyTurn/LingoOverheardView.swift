import SwiftUI

/// Overheard: the round, and the reason Lingo exists.
///
/// A flashcard asked her to recall a definition, which is a thing she will
/// never have to do. This asks the question she actually gets asked: he says
/// "squeaky bum time", the telly says "they've gone route one", what did that
/// mean. Snippet, three options, then the reveal with a line she can say back.
///
/// Seven items, dealt by `LingoWeekendDeck` from this weekend's fixture. No
/// re-queue of a missed word inside the round: the same snippet with the same
/// three options in the same order tests where her thumb was. Across rounds
/// the same defence is the session's `salt`, which reshuffles the options on
/// every deal while holding them still for the round she is in.
struct LingoOverheardView: View {
    let content: LingoContent
    /// For the "Lines that use this" jump on a reveal.
    let sayThis: SayThisContent
    @Bindable var store: MyTurnStore
    /// This weekend, for the line the end card offers her to use at it.
    let context: MatchContext
    /// The dealt words that name a real player from this fixture, keyed by
    /// term id (`PlayerSlots`). At most two of the seven, and empty whenever
    /// nothing resolved. Only the round reads it: the glossary keeps rendering
    /// the plain text, because a name in a definition is noise when she is
    /// looking up what a word means mid-match.
    var named: [String: LingoTerm] = [:]
    /// A fresh seven from the same weekend, from the end card.
    let onDealAgain: () -> Void
    /// "The words" on an unfinished round: the round is kept exactly where it
    /// is and the landing screen comes back, the way Quiz's "Packs" works. The
    /// four-second look-up is the reason Lingo exists; it cannot cost a round.
    let onPause: () -> Void
    @Environment(AppState.self) private var appState

    private func term(_ id: String) -> LingoTerm? { named[id] ?? content.terms.first { $0.id == id } }

    /// The word list the round speaks from. Used for the line the end card
    /// offers so a committed line carries the name she just read on the card —
    /// the heading, the bubble and the settle row a week later all have to say
    /// the same words.
    private var terms: [LingoTerm] {
        named.isEmpty ? content.terms : content.terms.map { named[$0.id] ?? $0 }
    }

    var body: some View {
        // Its own stack rather than borrowing the parent's: the round is a
        // screen, and one child in `LingoView`'s VStack is easier to reason
        // about than a tuple spliced into it.
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            if let session = store.drillSession {
                if session.finished {
                    finished(session)
                } else if let id = session.queue[safe: session.index], let term = term(id),
                          let options = LingoWeekendDeck.options(for: term, salt: session.salt) {
                    header(session)
                    item(session, term: term, options: options)
                } else {
                    staleRound
                }
            }
        }
    }

    // MARK: Where she is

    @ViewBuilder
    private func header(_ session: MyTurnStore.DrillSession) -> some View {
        HStack {
            Button {
                onPause()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("The words").font(.jakarta(15, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(.warmWhite.opacity(0.75))
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to the words. This round is paused.")

            Spacer(minLength: 0)

            Text("\(session.index + 1) of \(session.queue.count)")
                .font(.jakarta(13, weight: .semiBold))
                .foregroundColor(.warmWhite.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel("Word \(session.index + 1) of \(session.queue.count)")
        }
        .padding(.bottom, 4)
    }

    // MARK: One snippet

    @ViewBuilder
    private func item(_ session: MyTurnStore.DrillSession, term: LingoTerm,
                      options: (options: [String], answer: Int)) -> some View {
        if let speaker = term.speaker {
            Text(appState.personalise(speaker.label).uppercased())
                .font(.jakarta(10, weight: .bold))
                .tracking(1)
                .foregroundColor(.hotRose)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.hotRose.opacity(0.15)))
                .accessibilityLabel("Said by \(appState.personalise(speaker.label))")
        }

        Text(snippet(term))
            .font(.jakarta(19, weight: .regular))
            .foregroundColor(.textPrimaryOnCard)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(Layout.cardCornerRadius)

        Text(question(term))
            .font(.jakarta(17, weight: .bold))
            .foregroundColor(.warmWhite)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)

        ForEach(Array(options.options.enumerated()), id: \.offset) { idx, option in
            MyTurnOptionButton(text: option, index: idx, answer: options.answer,
                               selected: session.selected) { picked in
                store.answerDrill(picked, correct: picked == options.answer)
            }
        }

        if let selected = session.selected {
            reveal(session, term: term, correct: selected == options.answer)
        }
    }

    /// The line as it was said, with the phrase itself in bold. `overheardTerm`
    /// is emitted by the build script as the literal substring, so this is a
    /// plain `range(of:)` and not a matching rule.
    ///
    /// `options(for:)` requires `overheard`, so a card on screen always has one.
    private func snippet(_ term: LingoTerm) -> AttributedString {
        var text = AttributedString(term.overheard ?? "")
        if let needle = term.overheardTerm, let range = text.range(of: needle) {
            text[range].font = .jakarta(19, weight: .bold)
        }
        return text
    }

    /// "What does he mean?" when it was him talking. The followed person's
    /// pronoun follows the relationship, so a friend or a parent gets "they".
    private func question(_ term: LingoTerm) -> String {
        guard term.speaker == .him else { return "What does that mean?" }
        return appState.usesHeVoice ? "What does he mean?" : "What do they mean?"
    }

    // MARK: The reveal

    @ViewBuilder
    private func reveal(_ session: MyTurnStore.DrillSession, term: LingoTerm, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(correct ? "Right." : "Not that one.")
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(correct ? .hotRose : .warmWhite)

            Text(term.term)
                .font(.jakarta(18, weight: .bold))
                .foregroundColor(.warmWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text(term.meaning)
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let sayIt = term.sayIt {
                VStack(alignment: .leading, spacing: 5) {
                    Text("NOW YOU SAY")
                        .font(.jakarta(10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.hotRose)
                    Text(sayIt)
                        .font(.jakarta(15, weight: .semiBold))
                        .foregroundColor(.warmWhite)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.hotRose.opacity(0.12))
                .cornerRadius(10)
                .padding(.top, 2)
            }

            if let situation = situation(using: term) {
                Button {
                    store.sayThisSituationId = situation.id
                    withAnimation(.spring(duration: 0.25)) { store.lastModule = .sayThis }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Lines that use this")
                            .font(.jakarta(14, weight: .semiBold))
                    }
                    .foregroundColor(.hotRose)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lines that use \(term.term), in Say This")
            }

            Button {
                store.nextDrillCard()
            } label: {
                Text(session.index + 1 >= session.queue.count ? "See how you did" : "Next")
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .padding(.vertical, 4)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel(session.index + 1 >= session.queue.count
                                ? "See how you did" : "Next word")
        }
        .padding(14)
        .background(Color.warmWhite.opacity(0.06))
        .cornerRadius(Layout.cardCornerRadius)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// The Say This situation whose lines lean on this word, if there is one.
    private func situation(using term: LingoTerm) -> Situation? {
        sayThis.situations.first { $0.lines.contains { $0.lingo == term.id } }
    }

    // MARK: The end

    @ViewBuilder
    private func finished(_ session: MyTurnStore.DrillSession) -> some View {
        Text(session.queue.count == LingoWeekendDeck.roundLength ? "That's seven." : "That's the round.")
            .font(.jakarta(30, weight: .bold))
            .foregroundColor(.warmWhite)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)

        commitment(session)

        HypeCard(scoreLine: "You got \(session.knew) of \(session.queue.count).", hype: session.hypeLine)
            .task(id: session.finished) {
                // Read the session back out of the store: the screenshot
                // harness finishes a round after this body was built, and a
                // stale snapshot here would band the wrong score.
                guard let s = store.drillSession, s.finished, s.hypeLine == nil else { return }
                let band = HypeCategory.band(score: s.knew, of: s.queue.count)
                store.drillSession?.hypeLine = Hype.line(band, store: store)
            }

        // Only when she actually missed one: on seven out of seven the line
        // is a promise about nothing.
        if session.knew < session.queue.count {
            Text("The ones you missed come round again.")
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }

        Button {
            onDealAgain()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                Text("Go again")
                    .font(.jakarta(18, weight: .bold))
            }
            .foregroundColor(.warmWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.hotRose)
            .cornerRadius(Layout.buttonCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.queue.count == LingoWeekendDeck.roundLength
                            ? "Go again. Another seven words for this weekend."
                            : "Go again. Another round for this weekend.")

        Button {
            store.endDrill()
        } label: {
            Text("Back to the words")
                .font(.jakarta(15, weight: .semiBold))
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to the words")
    }

    /// One line out of the seven, and an offer to actually use it.
    ///
    /// The round used to end with a number, which she walked into the room
    /// with nothing holding. This is the one thing it leaves behind: a line
    /// she got right, named for the game it fits, and a single button. Not
    /// tapping costs nothing and leaves nothing behind either — there is no
    /// second ask, and the landing only mentions it once the game has been
    /// played.
    ///
    /// Nothing at all after a game, or when the round produced no right
    /// answer: both are handled inside `LingoWeekendDeck.offer`.
    @ViewBuilder
    private func commitment(_ session: MyTurnStore.DrillSession) -> some View {
        let saved = store.committedLine(fixture: context.fixtureKey)
        // The saved one wins: it holds the words as they were shown when she
        // said yes, and a redraw must not offer her a different line.
        if let line = saved ?? LingoWeekendDeck.offer(
            terms: terms, knewIds: session.knewIds, context: context,
            now: Date(), personalise: appState.personalise) {
            VStack(alignment: .leading, spacing: 10) {
                Text("For \(line.occasion)")
                    .font(.jakarta(17, weight: .bold))
                    .foregroundColor(.warmWhite)
                    .fixedSize(horizontal: false, vertical: true)

                Text(line.line)
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if saved == nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { store.commitLine(line) }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("I'll use it")
                            .font(.jakarta(16, weight: .semiBold))
                            .foregroundColor(.warmWhite)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .background(Color.hotRose)
                            .cornerRadius(Layout.buttonCornerRadius)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("I'll use it. Keeps this line for \(line.occasion).")
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Saved for \(line.occasion)")
                            .font(.jakarta(15, weight: .semiBold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundColor(.hotRose)
                    .frame(minHeight: 46, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warmWhite.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.35), lineWidth: 1))
            .cornerRadius(Layout.cardCornerRadius)
            .padding(.bottom, 2)
        }
    }

    /// A round dealt before the content was refreshed, or resumed from the old
    /// flashcard deck: the word she is on has no options any more.
    @ViewBuilder
    private var staleRound: some View {
        // Not "deal a fresh seven": the hero that would deal one is hidden
        // exactly when this card shows, because both need playable words.
        MyTurnEmptyText(text: "Those words have moved on. Search for the one you heard.")
        Button {
            store.endDrill()
        } label: {
            Text("Back to the words")
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius).stroke(Color.hotRose, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to the words")
    }
}
