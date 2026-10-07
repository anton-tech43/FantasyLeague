import SwiftUI

/// The Matchday tab (2026-10-07): "After {opponent}", the game just played,
/// and "Before {next}", which is Pre-game, moved here from My Turn.
///
/// It opens on After for a day after the whistle, unless the next game is
/// inside that day too; otherwise on Before. Both sections stay mounted
/// (opacity-switched, as My Turn does) so a round in progress survives a look
/// at the other one.
///
/// After is laid out to Anton's design (mockup "After the whistle", v21): one
/// rounded pink result card, then square rose-outlined boxes. Every line in
/// it comes ready-made on the `last_match` card; this view only lays it out.
struct MatchdayView: View {
    @Environment(AppState.self) private var appState
    @State private var store = MyTurnStore.shared
    @State private var content = MyTurnContentService.shared
    @State private var live = LiveClubPackService.shared
    /// What she picked. Nil means the default for this moment, so a new game
    /// opens on its own default rather than on whatever she last tapped.
    @State private var picked: MatchdaySection?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if lastMatch != nil {
                    segments
                        .padding(.horizontal, Layout.screenPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }

                ZStack {
                    if let card = lastMatch, let team = appState.selectedTeam {
                        AfterView(card: card, team: team, next: live.page?.cards.nextFixture)
                            .opacity(section == .after ? 1 : 0)
                            .allowsHitTesting(section == .after)
                            .accessibilityHidden(section != .after)
                    }
                    LingoView(content: content.lingo, store: store,
                              team: appState.selectedTeam, page: live.page, mode: .prep)
                        .opacity(section == .before ? 1 : 0)
                        .allowsHitTesting(section == .before)
                        .accessibilityHidden(section != .before)
                    HypeStreakOverlay(store: store)
                }
                .id(store.resetTick)
            }
        }
        .navigationTitle("Matchday")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // A new game starts from its own default.
        .onChange(of: lastMatch?.fixtureId) { _, _ in picked = nil }
        .onChange(of: appState.requestedMatchdaySection, initial: true) { _, wanted in
            guard let wanted else { return }
            picked = wanted
            appState.requestedMatchdaySection = nil
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-gdMatchdaySection"), i + 1 < args.count {
                picked = args[i + 1] == "after" ? .after : .before
            }
        }
        #endif
    }

    // MARK: State

    private var lastMatch: LastMatchCard? {
        #if DEBUG
        if let sample = LastMatchCard.debugSample { return sample }
        #endif
        guard let card = live.page?.cards.lastMatch, !card.isExpired else { return nil }
        return card
    }

    private var nextContext: MatchContext {
        MatchContext(page: live.page, team: appState.selectedTeam, now: .gdNow, preferBefore: true)
    }

    private var nextKickoff: Date? {
        if case .before(_, let kickoff) = nextContext.phase { return kickoff }
        return nil
    }

    private var opening: MatchdaySection {
        MatchdaySection.opening(lastFinished: lastMatch?.finishedDate, nextKickoff: nextKickoff, now: .gdNow)
    }

    private var section: MatchdaySection {
        lastMatch == nil ? .before : (picked ?? opening)
    }

    // MARK: Segments

    private var afterLabel: String { "After \(Self.short(lastMatch?.opponent ?? ""))" }

    private var beforeLabel: String {
        if case .before(let opponent, _) = nextContext.phase { return "Before \(Self.short(opponent))" }
        return "Pre-game"
    }

    /// "Manchester United" → "Man Utd" when it is one of ours; anyone else as
    /// the feed names them.
    static func short(_ name: String) -> String {
        Team.allCases.first { MatchContext.sameClub($0.displayName, name) }?.shortName ?? name
    }

    /// Same language as My Turn's control: the selected half is a rose pill.
    private var segments: some View {
        HStack(spacing: 4) {
            segment(.after, afterLabel, dot: opening == .after && section != .after)
            segment(.before, beforeLabel, dot: false)
        }
    }

    private func segment(_ s: MatchdaySection, _ label: String, dot: Bool) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { picked = s }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.jakarta(15, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(section == s ? Color.hotRose : Color.clear)
                .foregroundColor(section == s ? .warmWhite : .warmWhite.opacity(0.6))
                .cornerRadius(12)
                .overlay(alignment: .topTrailing) {
                    if dot {
                        Circle().fill(Color.gold).frame(width: 7, height: 7).padding(.top, 8).padding(.trailing, 14)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dot ? "\(label), new" : label)
        .accessibilityAddTraits(section == s ? .isSelected : [])
    }
}

extension MatchdaySection {
    /// After for a day from the whistle, unless the next game is inside that
    /// day as well, when getting ready for it matters more.
    static func opening(lastFinished: Date?, nextKickoff: Date?, now: Date) -> MatchdaySection {
        let day: TimeInterval = 24 * 3600
        guard let finished = lastFinished, now.timeIntervalSince(finished) < day else { return .before }
        if let kickoff = nextKickoff, kickoff.timeIntervalSince(now) < day { return .before }
        return .after
    }

    #if DEBUG
    static func selfCheck() -> Bool {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let h: TimeInterval = 3600
        return opening(lastFinished: now - 2 * h, nextKickoff: now + 72 * h, now: now) == .after
            && opening(lastFinished: now - 30 * h, nextKickoff: now + 72 * h, now: now) == .before
            && opening(lastFinished: now - 2 * h, nextKickoff: now + 20 * h, now: now) == .before
            && opening(lastFinished: now - 2 * h, nextKickoff: nil, now: now) == .after
            && opening(lastFinished: nil, nextKickoff: nil, now: now) == .before
    }
    #endif
}

// MARK: - After

private struct AfterView: View {
    let card: LastMatchCard
    let team: Team
    let next: NextFixtureCard?
    @State private var article: ContentItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ResultCard(card: card, team: team)
                    .containerRelativeFrame(.vertical) { h, _ in h * 0.82 }

                OutlinedBox(label: "Say this now:", compact: true) {
                    Quote(text: card.talkingPoint, size: 13.5)
                }

                OutlinedBox(label: "Goal scorers:") {
                    if card.goals.isEmpty {
                        Text("No goals. Nothing for either side to celebrate.")
                            .font(.jakarta(13.5, weight: .italic))
                            .foregroundColor(.softBlush)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ScorerPager(goals: card.goals, team: team, opponent: card.opponent)
                    }
                }

                if !card.numbers.isEmpty {
                    OutlinedBox(label: "Three numbers that matter:") {
                        NumbersGrid(numbers: card.numbers)
                    }
                }

                VStack(spacing: 0) {
                    if let article {
                        NavigationLink(value: ContentDetailDestination(
                            contentId: article.id, scrollToTalkingPoints: false, preloadedItem: article)) {
                            row { Text("The full story").font(.jakarta(14, weight: .bold)); Spacer()
                                  Text("›").font(.jakarta(14, weight: .bold)).foregroundColor(.hotRose) }
                        }
                        .buttonStyle(.plain)
                    }
                    if let nextLine {
                        row { Text(nextLine).font(.jakarta(14, weight: .bold)); Spacer() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .task(id: card.fixtureId) {
            article = try? await APIClient.shared.fetchMatchArticle(fixtureId: card.fixtureId, teamId: team.rawValue)
        }
    }

    private func row<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack { c() }
            .foregroundColor(.warmWhite)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .overlay(alignment: .top) { Rectangle().fill(Color(hex: "#3D2B3E")).frame(height: 1) }
            .contentShape(Rectangle())
    }

    /// "Next: Lille (home), Tuesday", or the date when it is more than a week off.
    private var nextLine: String? {
        guard let next, let date = ISO8601DateFormatter.lenient(next.date), date > .gdNow else { return nil }
        let f = DateFormatter()
        f.dateFormat = date.timeIntervalSince(.gdNow) < 6 * 86_400 ? "EEEE" : "d MMM"
        return "Next: \(MatchdayView.short(next.opponent)) (\(next.venue.lowercased())), \(f.string(from: date))"
    }
}

/// The rounded pink card: the score in League Spartan Bold, the verdict in a
/// serif on two rows. Pink for a win or a loss, blush (with mauve type) after
/// a draw.
private struct ResultCard: View {
    let card: LastMatchCard
    let team: Team

    private var fill: Color {
        switch card.state {
        case .win: return .hotRose
        // Pink for a loss too (Anton, 2026-10-07): the brand has no red, and
        // the score and the verdict already say they lost.
        case .loss: return .hotRose
        case .draw: return .softBlush
        }
    }
    private var ink: Color { card.state == .draw ? .deepMauve : .white }

    private var scoreLine: String {
        let us = team.shortName, them = MatchdayView.short(card.opponent)
        return card.venue == "away"
            ? "\(them) \(card.oppScore)-\(card.teamScore) \(us)"
            : "\(us) \(card.teamScore)-\(card.oppScore) \(them)"
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - 36
            VStack(alignment: .leading, spacing: 10) {
                Text(scoreLine)
                    .font(.spartanBold(30))
                    .tracking(-0.045 * 30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(Self.verdict(card.verdict, size: Self.verdictSize(card.verdict, width: width)))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(ink)
            .padding(.horizontal, 18)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    /// 18pt, stepped down half a point at a time until the verdict sits on
    /// two rows (Anton, 2026-10-07), the way the feed sizes its headline.
    static func verdictSize(_ text: String, width: CGFloat) -> CGFloat {
        for size in stride(from: 18.0, through: 12.0, by: -0.5) {
            guard let font = UIFont(name: "CormorantGaramond-Medium", size: size) else { return 16 }
            let h = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                     options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil).height
            if h <= font.lineHeight * 2 + 1 { return size }
        }
        return 12
    }

    /// "88th" with its suffix raised, as in the design.
    static func verdict(_ text: String, size: CGFloat) -> AttributedString {
        var out = AttributedString(text)
        out.font = .garamond(size)
        if let r = text.range(of: #"\d+(st|nd|rd|th)\b"#, options: .regularExpression),
           let found = out.range(of: String(text[r])) {
            let suffix = out.index(found.upperBound, offsetByCharacters: -2)..<found.upperBound
            out[suffix].font = .garamond(size * 0.6)
            out[suffix].baselineOffset = size * 0.35
        }
        return out
    }
}

/// A square box with a 4pt rose outline and a bold-italic label. Tall and
/// centred, so each box is one thing on the screen; "Say this now" is the
/// compact one.
private struct OutlinedBox<Content: View>: View {
    let label: String
    var compact = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.jakarta(15, weight: .boldItalic))
                .foregroundColor(.softBlush)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, compact ? 22 : 30)
        .padding(.horizontal, compact ? 18 : 20)
        .frame(minHeight: compact ? nil : 230)
        .overlay(Rectangle().strokeBorder(Color.hotRose, lineWidth: 4))
    }
}

private struct Quote: View {
    let text: String
    let size: CGFloat
    var body: some View {
        Text("\u{201C}\(text.hasSuffix(".") ? String(text.dropLast()) : text)\u{201D}")
            .font(.jakarta(size, weight: .italic))
            .foregroundColor(.softBlush)
            .lineSpacing(size * 0.35)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Every goal, both sides, one at a time: the sticker when we have one, "7.
/// Bukayo Saka", the score it made and one line. A goal with no sticker (the
/// other side's, or anyone not yet imported) keeps the name and the line.
/// The rose chevron (or a swipe) goes to the next.
private struct ScorerPager: View {
    let goals: [LastMatchCard.Goal]
    let team: Team
    let opponent: String
    @State private var index = 0

    /// The club whose portraits to look in: his, or the opponent's when it is
    /// one of the twenty. Nil for anyone else, and the name stands alone.
    private func club(_ g: LastMatchCard.Goal) -> String? {
        g.ours ? team.rawValue : Team.allCases.first { MatchContext.sameClub($0.displayName, opponent) }?.rawValue
    }

    var body: some View {
        let i = min(index, goals.count - 1)
        let goal = goals[i]
        let asset = goal.player == "Own goal" ? nil : PlayerPortrait.asset(club: club(goal), name: goal.player)
        VStack(spacing: 2) {
            if let asset {
                GeometryReader { geo in
                    ZStack {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.96)
                            .accessibilityHidden(true)
                        chevrons(i)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .aspectRatio(1.05, contentMode: .fit)
                .padding(.top, 8)
            } else {
                // No sticker: the name carries the slide, with the chevrons
                // either side of it.
                ZStack { chevrons(i) }
                    .frame(height: 44)
                    .padding(.top, 8)
            }

            Text(nameLine(goal))
                .font(.spartanBold(30))
                .tracking(-0.045 * 30)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(goal.score), \(goal.minute)")
                    .font(.jakarta(13, weight: .boldItalic))
                    .foregroundColor(.softBlush)
                Quote(text: goal.line, size: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

            if goals.count > 1 {
                HStack(spacing: 5) {
                    ForEach(goals.indices, id: \.self) { k in
                        Circle().fill(k == i ? Color.hotRose : Color.softBlush.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 8)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { v in
            if v.translation.width < -40, i < goals.count - 1 { withAnimation { index = i + 1 } }
            if v.translation.width > 40, i > 0 { withAnimation { index = i - 1 } }
        })
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { dir in
            if dir == .increment, i < goals.count - 1 { index = i + 1 }
            if dir == .decrement, i > 0 { index = i - 1 }
        }
        .onChange(of: goals) { _, _ in index = 0 }
    }

    @ViewBuilder
    private func chevrons(_ i: Int) -> some View {
        if i < goals.count - 1 { chevron(right: true) { index = i + 1 } }
        if i > 0 { chevron(right: false) { index = i - 1 } }
    }

    private func chevron(right: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { action() } }) {
            Image(systemName: right ? "chevron.right" : "chevron.left")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.hotRose)
                .frame(width: 28, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: right ? .trailing : .leading)
        .offset(x: right ? 12 : -12)
        .accessibilityLabel(right ? "Next scorer" : "Previous scorer")
    }

    /// "7. Bukayo Saka". The feed abbreviates some first names ("B. Saka"),
    /// and "7. B. Saka" reads like a list, so an initial is dropped.
    private func nameLine(_ g: LastMatchCard.Goal) -> String {
        let name = g.player.replacingOccurrences(of: #"^\p{Lu}\.\s+"#, with: "", options: .regularExpression)
        return g.number.map { "\($0). \(name)" } ?? name
    }
}

/// One column for the numbers, so every number and every caption starts on
/// the same line (the mockup's numbers drifted, 2026-10-07).
private struct NumbersGrid: View {
    let numbers: [LastMatchCard.Number]
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 18) {
            ForEach(numbers, id: \.self) { n in
                GridRow {
                    Text(n.value)
                        .font(.custom("LeagueSpartan-Black", size: 24))
                        .monospacedDigit()
                        .foregroundColor(.warmWhite)
                    Text(n.caption)
                        .font(.jakarta(13))
                        .foregroundColor(.softBlush)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        // Centre the first line on the number rather than
                        // sitting it on the number's baseline, where a small
                        // line beside a 24pt figure read as dropped (Anton,
                        // 2026-10-07): the figure's cap height is ~17pt, the
                        // caption's x-height ~7pt: their middles meet with the
                        // caption's baseline 5pt above the figure's.
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] + 5 }
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Screenshot harness

#if DEBUG
extension LastMatchCard {
    /// `-gdLastMatch late|crush|bore|unlucky`: the mockup's four games, so
    /// After can be checked before match-watcher has written a real card.
    static var debugSample: LastMatchCard? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-gdLastMatch"), i + 1 < args.count else { return nil }
        let iso = ISO8601DateFormatter()
        let finished = iso.string(from: Date.gdNow.addingTimeInterval(-2 * 3600))
        let kickoff = iso.string(from: Date.gdNow.addingTimeInterval(-4 * 3600))
        let expires = iso.string(from: Date.gdNow.addingTimeInterval(7 * 86_400))
        func card(_ gf: Int, _ ga: Int, _ state: TeamPostMatchCard.TeamPostMatchState, _ verdict: String, _ tp: String,
                  _ goals: [Goal], _ numbers: [(String, String)]) -> LastMatchCard {
            LastMatchCard(fixtureId: 9_000_000 + gf * 10 + ga, kickoff: kickoff, finishedAt: finished, competition: nil,
                          opponent: "Leeds", venue: "home", teamScore: gf, oppScore: ga, state: state,
                          verdict: verdict, talkingPoint: tp, goals: goals,
                          numbers: numbers.map { Number(value: $0.0, caption: $0.1) }, expiresAt: expires)
        }
        func g(_ p: String, _ n: Int, _ m: String, _ s: String, _ l: String) -> Goal {
            Goal(player: p, apiPlayerId: nil, number: n, minute: m, score: s, line: l)
        }
        switch args[i + 1] {
        case "crush":
            return card(4, 0, .win, "Over long before the end. Leeds never had a shot on target.", "They made that look easy.",
                        [g("Bukayo Saka", 7, "12'", "1–0 Arsenal", "A tap-in after Leeds lost it at the back."),
                         g("Declan Rice", 41, "33'", "2–0 Arsenal", "His 3rd goal of the season."),
                         g("Kai Havertz", 29, "41'", "3–0 Arsenal", "Ran through on his own and slotted it in."),
                         g("Gabriel Martinelli", 11, "77'", "4–0 Arsenal", "On as a sub, scored with his first touch.")],
                        [("0", "Leeds shots on target. In the whole game."), ("3–0", "at half-time. The second half was a formality."), ("17–4", "shots. Arsenal were all over them.")])
        case "bore":
            return card(0, 0, .draw, "Ninety minutes, 2 shots on target between them.", "Not one for the highlights, was it?", [],
                        [("68%", "possession, and nothing to show for it."), ("8–5", "shots. Not much in it."), ("1–1", "shots on target.")])
        case "unlucky":
            return card(0, 1, .loss, "Arsenal had the chances, Leeds had the goal.", "You can't fault the effort. It just wouldn't go in.",
                        [Goal(ours: false, team: "Leeds", player: "Dominic Calvert-Lewin", apiPlayerId: nil, number: 9,
                              minute: "71'", score: "1–0 Leeds", line: "His 5th goal of the season.")],
                        [("21–5", "shots. One of those nights."), ("2.4", "expected goals for Arsenal. On a normal night, that's 2 goals."), ("71%", "possession, and nothing to show for it.")])
        default:
            return card(2, 1, .win, "Won it in the 88th minute after Leeds had more of the chances.", "That was closer than it should have been.",
                        [g("Kai Havertz", 29, "23'", "1–0 Arsenal", "His 3rd goal of the season."),
                         Goal(ours: false, team: "Leeds", player: "Dominic Calvert-Lewin", apiPlayerId: nil, number: 9,
                              minute: "61'", score: "1–1 Leeds", line: "The equaliser."),
                         g("Bukayo Saka", 7, "88'", "2–1 Arsenal", "Curled in from outside the box.")],
                        [("88'", "when the winner went in."), ("6–9", "shots. Leeds had more of it, Arsenal had the goals."), ("2–1", "shots on target.")])
        }
    }
}
#endif
