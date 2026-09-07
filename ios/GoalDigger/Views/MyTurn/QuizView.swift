import SwiftUI

/// Module 3 — Quiz. Packs of ten-question rounds with instant feedback; the
/// explanation is where the learning happens, the score is not. No streaks,
/// no daily goals, no reminders. A round in progress is paused, never lost.
struct QuizView: View {
    let content: QuizContent
    @Bindable var store: MyTurnStore
    /// His Team's selected club (Team.rawValue, snake_case). Nil hides the
    /// "His Club" pack entirely rather than showing an empty one.
    let clubId: String?

    private var visiblePacks: [QuizPack] {
        let general = content.packs.filter { !$0.isClubPack }
        guard let clubId else { return general }
        let kebab = "club-" + clubId.replacingOccurrences(of: "_", with: "-")
        if let his = content.packs.first(where: { $0.id == kebab }) {
            return general + [his]
        }
        return general
    }

    private var round: MyTurnStore.QuizRound? { store.quizRound }
    private var roundPack: QuizPack? { round.flatMap { r in content.packs.first { $0.id == r.packId } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                if let round, let pack = roundPack {
                    if round.finished {
                        resultView(round, pack: pack)
                    } else {
                        questionView(round, pack: pack)
                    }
                } else {
                    packList
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: round?.index)
        .animation(.easeInOut(duration: 0.2), value: round?.finished)
    }

    // MARK: Pack list

    @ViewBuilder
    private var packList: some View {
        MyTurnSectionLabel(text: "Pick a pack")
        ForEach(visiblePacks) { pack in
            let progress = store.progress(for: pack.id)
            Button {
                store.startRound(pack: pack)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                MyTurnRow(
                    title: pack.isClubPack ? "His Club: \(pack.label)" : pack.label,
                    subtitle: progress.played == 0 ? "\(pack.questions.count) questions" : "Best: \(progress.best) / 10"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.hotRose)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Question

    @ViewBuilder
    private func questionView(_ round: MyTurnStore.QuizRound, pack: QuizPack) -> some View {
        let qid = round.questionIds[round.index]
        if let q = pack.questions.first(where: { $0.id == qid }) {
            // No pause button: leaving the tab, or the app, keeps the round
            // exactly here. Only "Next pack" on the result screen ends it.
            Text("Question \(round.index + 1) of \(round.questionIds.count)")
                .font(.sectionHeader).tracking(1)
                .foregroundColor(.mutedText)

            Text(q.question)
                .font(.jakarta(20, weight: .bold))
                .foregroundColor(.warmWhite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                optionButton(idx: idx, text: option, question: q, selected: round.selected)
            }

            if let selected = round.selected {
                let correct = selected == q.answer
                VStack(alignment: .leading, spacing: 8) {
                    Text(correct ? "Right." : "Not that one.")
                        .font(.jakarta(17, weight: .bold))
                        .foregroundColor(correct ? .hotRose : .warmWhite)
                    Text(q.explanation)
                        .font(.jakarta(15, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.9))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        store.nextQuestion()
                    } label: {
                        Text(round.index + 1 >= round.questionIds.count ? "See the score" : "Next")
                            .font(.jakarta(16, weight: .semiBold))
                            .foregroundColor(.warmWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.hotRose)
                            .cornerRadius(Layout.buttonCornerRadius)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(14)
                .background(Color.warmWhite.opacity(0.06))
                .cornerRadius(Layout.cardCornerRadius)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private func optionButton(idx: Int, text: String, question: MyTurnQuestion, selected: Int?) -> some View {
        let answered = selected != nil
        let isCorrect = idx == question.answer
        let isPicked = idx == selected
        let background: Color = {
            guard answered else { return .cardBackground }
            if isCorrect { return Color.hotRose.opacity(0.18) }
            if isPicked { return Color.red.opacity(0.10) }
            return .cardBackground
        }()
        return Button {
            guard !answered else { return }
            store.answer(idx, correct: isCorrect, questionId: question.id)
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
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7))
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
    }

    // MARK: Result

    @ViewBuilder
    private func resultView(_ round: MyTurnStore.QuizRound, pack: QuizPack) -> some View {
        Text("\(round.score) out of \(round.questionIds.count).")
            .font(.jakarta(30, weight: .bold))
            .foregroundColor(.warmWhite)

        if !round.missedIds.isEmpty {
            MyTurnSectionLabel(text: "The ones you missed")
                .padding(.top, 8)
            ForEach(round.missedIds, id: \.self) { id in
                if let q = pack.questions.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(q.question)
                            .font(.jakarta(14, weight: .semiBold))
                            .foregroundColor(.textPrimaryOnCard)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(q.options[q.answer])
                            .font(.jakarta(14, weight: .regular))
                            .foregroundColor(.hotRose)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardBackground)
                    .cornerRadius(Layout.cardCornerRadius)
                }
            }

            Button {
                store.startRetryRound(pack: pack, missedIds: round.missedIds)
            } label: {
                Text("Retry the \(Self.words(round.missedIds.count)) you missed")
                    .font(.jakarta(16, weight: .semiBold))
                    .foregroundColor(.warmWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        } else {
            Text("Every single one. He's got competition.")
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.8))
        }

        Button {
            store.endRound()
        } label: {
            Text("Next pack")
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius).stroke(Color.hotRose, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private static func words(_ n: Int) -> String {
        let w = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return (1...10).contains(n) ? w[n] : "\(n)"
    }
}
