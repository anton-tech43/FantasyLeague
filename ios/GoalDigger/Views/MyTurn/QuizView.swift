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
    /// "His club, right now", built on the device from the team page
    /// (LiveClubPack). Nil until the page has loaded or when no club is picked.
    let livePack: QuizPack?

    private var allPacks: [QuizPack] { content.packs + (livePack.map { [$0] } ?? []) }

    private var visiblePacks: [QuizPack] {
        let general = content.packs.filter { !$0.isClubPack }
        guard let clubId else { return general }
        var his: [QuizPack] = livePack.map { [$0] } ?? []
        let kebab = "club-" + clubId.replacingOccurrences(of: "_", with: "-")
        if let history = content.packs.first(where: { $0.id == kebab }) { his.append(history) }
        return his + general
    }

    private var round: MyTurnStore.QuizRound? { store.quizRound }
    private var roundPack: QuizPack? { round.flatMap { r in allPacks.first { $0.id == r.packId } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                if let round, let pack = roundPack {
                    if round.finished {
                        resultView(round, pack: pack)
                    } else if pack.questions.contains(where: { $0.id == round.questionIds[round.index] }) {
                        questionView(round, pack: pack)
                    } else {
                        staleRound
                    }
                } else if round != nil, livePack == nil, round?.packId == LiveClubPack.packId {
                    // The live pack is still building; keep the round.
                    MyTurnEmptyText(text: "Loading his club…")
                } else if round != nil {
                    staleRound
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

    /// A round whose pack or question no longer exists — the live pack was
    /// rebuilt after the team page changed, or the content was updated.
    @ViewBuilder
    private var staleRound: some View {
        MyTurnEmptyText(text: "That pack has been refreshed since you started. Pick it again.")
        Button { store.endRound() } label: {
            Text("Back to packs")
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(.hotRose)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: Layout.buttonCornerRadius).stroke(Color.hotRose, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Pack list

    private func packTitle(_ pack: QuizPack) -> String {
        if pack.id == LiveClubPack.packId { return pack.label }
        return pack.isClubPack ? "His club, the history" : pack.label
    }

    private func packSubtitle(_ pack: QuizPack) -> String {
        let progress = store.progress(for: pack.id)
        if progress.played > 0 { return "Best: \(progress.best) / 10" }
        if pack.id == LiveClubPack.packId { return "Manager, players, last season. Updates with his team page." }
        if pack.isClubPack { return "\(pack.label) · \(pack.questions.count) questions" }
        return "\(pack.questions.count) questions"
    }

    @ViewBuilder
    private var packList: some View {
        MyTurnSectionLabel(text: "Pick a pack")
        ForEach(visiblePacks) { pack in
            Button {
                store.startRound(pack: pack)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                MyTurnRow(
                    title: packTitle(pack),
                    subtitle: packSubtitle(pack)
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

            if let image = q.image.flatMap(URL.init(string:)) {
                AsyncImage(url: image) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.warmWhite.opacity(0.4))
                    }
                }
                .frame(width: 140, height: 140)
                .background(Color.warmWhite.opacity(0.08))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.hotRose.opacity(0.5), lineWidth: 2))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .accessibilityLabel("Photo to identify")
            }

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
                    if let why = q.why {
                        Text(why)
                            .font(.jakarta(13, weight: .italic))
                            .foregroundColor(.warmWhite.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    if let use = q.use {
                        useLine(use, type: q.useType)
                    }
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

    /// The take-away: labelled with what it is for, set apart from the fact.
    /// This is the line she actually leaves the question with.
    private func useLine(_ use: String, type: QuestionUseType?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text((type?.label ?? "Use it").uppercased())
                .font(.jakarta(10, weight: .bold))
                .tracking(1)
                .foregroundColor(.hotRose)
            Text(use)
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
                        if let use = q.use {
                            Text(use)
                                .font(.jakarta(13, weight: .semiBold))
                                .foregroundColor(.textPrimaryOnCard)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
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
