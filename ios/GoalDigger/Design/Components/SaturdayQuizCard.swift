import SwiftUI

/// The Saturday Quiz surface (V1.1 task C3). Collapsed by default — a
/// hot-rose pill that invites a tap ("📝 Saturday Quiz — Liverpool weekend,
/// tap to play"). Expands inline to a 3-question state machine:
///
///   Q1 → reveal correctness + explainer → Q2 → reveal → Q3 → reveal → Result
///
/// The result screen shows score 0-3 with a soccer-ball emoji per correct
/// answer, plus a ShareLink that emits the row's share_template with
/// `{score}` substituted. T3+ tier-gated in FeedView; no gating logic here.
struct SaturdayQuizCard: View {
    let quiz: SaturdayQuiz

    // Quiz state machine.
    @State private var isExpanded = false
    @State private var currentIndex = 0
    /// Selected option for the current question. nil until she picks one.
    /// Once non-nil, we show the explainer and the "Next" affordance.
    @State private var selectedAnswer: Int?
    /// Tally of correct answers seen so far. Final value drives the score
    /// card. Reset on collapse so a re-open starts fresh.
    @State private var score = 0
    /// Once we've walked past the third explainer, flip to the score card.
    @State private var showResult = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                expandedView
            } else {
                collapsedPill
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(Color.hotRose.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(Layout.cardCornerRadius)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: currentIndex)
        .animation(.easeInOut(duration: 0.2), value: selectedAnswer)
        .animation(.easeInOut(duration: 0.2), value: showResult)
    }

    // MARK: - Collapsed pill

    private var collapsedPill: some View {
        Button {
            isExpanded = true
        } label: {
            HStack(spacing: 10) {
                // Tracker label — same uppercase, hot-rose treatment as
                // InsiderCard / TalkingPointCard so the surface feels
                // native to the feed.
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                    Text("SATURDAY QUIZ")
                        .font(.sectionHeader)
                        .tracking(1.5)
                }
                .foregroundColor(.hotRose)

                Text("·")
                    .font(.sectionHeader)
                    .foregroundColor(.mutedText)

                Text(quiz.headline)
                    .font(.jakarta(13, weight: .semiBold))
                    .foregroundColor(.textPrimaryOnCard)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("Tap to play")
                    .font(.jakarta(12, weight: .medium))
                    .foregroundColor(.hotRose)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.hotRose)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saturday Quiz: \(quiz.headline). Tap to play.")
    }

    // MARK: - Expanded — question + reveal, OR result card

    @ViewBuilder
    private var expandedView: some View {
        if showResult {
            resultCard
        } else {
            questionView
        }
    }

    private var questionView: some View {
        let question = quiz.questions[currentIndex]
        return VStack(alignment: .leading, spacing: 12) {
            // Header: tracker + progress
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                Text("SATURDAY QUIZ")
                    .font(.sectionHeader)
                    .tracking(1.5)
                Spacer()
                Text("\(currentIndex + 1) of \(quiz.questions.count)")
                    .font(.jakarta(11, weight: .medium))
                    .foregroundColor(.mutedText)
            }
            .foregroundColor(.hotRose)

            // Question text
            Text(question.q)
                .font(.jakarta(16, weight: .semiBold))
                .foregroundColor(.textPrimaryOnCard)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Options
            VStack(spacing: 8) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(
                        index: index,
                        text: option,
                        correctIndex: question.correct
                    )
                }
            }

            // Reveal — explainer + Next
            if let picked = selectedAnswer {
                Divider().padding(.vertical, 4)

                Text(question.explainer)
                    .font(.jakarta(14, weight: .regular))
                    .foregroundColor(.textSecondaryOnCard)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)

                Button {
                    advance(pickedCorrect: picked == question.correct)
                } label: {
                    HStack {
                        Spacer()
                        Text(currentIndex == quiz.questions.count - 1 ? "See your score" : "Next question")
                            .font(.jakarta(14, weight: .semiBold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.warmWhite)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// One option pill. Three render states: unpicked (default), picked + wrong
    /// (rose 8% tint, no border accent), picked + correct (rose border + check).
    /// After any pick, the correct option always reveals its check icon so
    /// she sees the right answer even if she got it wrong.
    private func optionButton(index: Int, text: String, correctIndex: Int) -> some View {
        let hasAnswered = selectedAnswer != nil
        let isPicked = selectedAnswer == index
        let isCorrect = index == correctIndex
        let showCheck = hasAnswered && isCorrect
        let showCross = hasAnswered && isPicked && !isCorrect

        return Button {
            // First pick locks the answer for this question.
            guard selectedAnswer == nil else { return }
            selectedAnswer = index
        } label: {
            HStack(spacing: 10) {
                // Index pip A/B/C — gives each option a visual handle so
                // her tap target is bigger than the text alone.
                Text(index < 3 ? ["A", "B", "C"][index] : String(UnicodeScalar(65 + index)!))
                    .font(.jakarta(11, weight: .bold))
                    .foregroundColor(hasAnswered && isCorrect ? .warmWhite : .hotRose)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(hasAnswered && isCorrect ? Color.hotRose : Color.hotRose.opacity(0.08))
                    )

                Text(text)
                    .font(.jakarta(15, weight: .medium))
                    .foregroundColor(.textPrimaryOnCard)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if showCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.hotRose)
                        .font(.system(size: 16, weight: .semibold))
                }
                if showCross {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.mutedText)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isPicked
                    ? Color.hotRose.opacity(0.08)
                    : Color.softBlush.opacity(0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        showCheck ? Color.hotRose.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(hasAnswered)
    }

    /// Final score card. Shows N/3 with a soccer-ball emoji per correct
    /// answer plus a ShareLink that emits the formatted share_template.
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                Text("SATURDAY QUIZ")
                    .font(.sectionHeader)
                    .tracking(1.5)
                Spacer()
            }
            .foregroundColor(.hotRose)

            Text("\(score)/\(quiz.questions.count) \(soccerBalls(for: score))")
                .font(.jakarta(28, weight: .bold))
                .foregroundColor(.textPrimaryOnCard)

            Text(scoreCommentary(for: score))
                .font(.jakarta(15, weight: .regular))
                .foregroundColor(.textSecondaryOnCard)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                // ShareLink — system share sheet, prefilled with the
                // share_template's {score} substituted. iOS handles the
                // social network picker; she lands on Messages, WhatsApp,
                // etc.
                ShareLink(item: shareText) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Share score")
                            .font(.jakarta(14, weight: .semiBold))
                    }
                    .foregroundColor(.warmWhite)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
                }

                Button {
                    // Reset & collapse — defensive reset so a re-open
                    // starts at Q1 with no leftover state.
                    resetState()
                } label: {
                    Text("Done")
                        .font(.jakarta(14, weight: .semiBold))
                        .foregroundColor(.hotRose)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.buttonCornerRadius)
                                .stroke(Color.hotRose.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - State transitions

    private func advance(pickedCorrect: Bool) {
        if pickedCorrect { score += 1 }
        if currentIndex == quiz.questions.count - 1 {
            showResult = true
        } else {
            currentIndex += 1
            selectedAnswer = nil
        }
    }

    private func resetState() {
        isExpanded = false
        currentIndex = 0
        selectedAnswer = nil
        score = 0
        showResult = false
    }

    // MARK: - Share + commentary helpers

    /// Fills the share_template's `{score}` placeholder with the actual
    /// score and returns the user-facing share string.
    private var shareText: String {
        quiz.shareTemplate.replacingOccurrences(of: "{score}", with: "\(score)")
    }

    /// One soccer-ball emoji per correct answer, e.g. "⚽⚽⚽" for 3/3.
    /// Empty string for 0/3 — no padding emoji so the score reads cleanly.
    private func soccerBalls(for score: Int) -> String {
        String(repeating: "⚽", count: max(0, score))
    }

    /// Sister-voice one-liner under the big score. No '?' or '!'.
    private func scoreCommentary(for score: Int) -> String {
        switch score {
        case 3: return "Top of the table. You've been paying attention."
        case 2: return "Solid. One slip but you're across the weekend."
        case 1: return "One on the board. Worth a scroll back through this week."
        default: return "A reset week. The cards are still here when you want them."
        }
    }
}
