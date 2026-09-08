import SwiftUI

/// Module 1 — Say This. A bank of lines sorted by what is happening.
///
/// Two levels, switched in place (no push, no back button in the nav bar):
/// level 1 lists situations in three groups with "Your lines" pinned on top;
/// level 2 shows the lines for one situation. Built for the four-second,
/// one-hand look during a match, so the line is the biggest thing in the row.
struct SayThisView: View {
    let content: SayThisContent
    /// For the "Lingo" chip on a line that leans on a real saying.
    let lingo: LingoContent
    @Bindable var store: MyTurnStore

    private var lingoById: [String: LingoTerm] {
        Dictionary(uniqueKeysWithValues: lingo.terms.map { ($0.id, $0) })
    }

    private var selected: Situation? {
        guard let id = store.sayThisSituationId else { return nil }
        return content.situations.first { $0.id == id }
    }

    /// Starred lines with their situation, for the "Your lines" section.
    private var starred: [(Situation, SayLine)] {
        let ids = store.starredLineIds
        var out: [(Situation, SayLine)] = []
        for s in content.situations {
            for l in s.lines where ids.contains(l.id) { out.append((s, l)) }
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                if let situation = selected {
                    linesLevel(situation)
                } else {
                    situationsLevel
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: store.sayThisSituationId)
    }

    // MARK: Level 1

    @ViewBuilder
    private var situationsLevel: some View {
        // Your lines — the starred ones, one tap from the top of the tab.
        MyTurnSectionLabel(text: "Your lines")
        if starred.isEmpty {
            Text("Star a line and it'll wait for you here.")
                .font(.jakarta(14, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
        } else {
            ForEach(starred, id: \.1.id) { situation, line in
                lineRow(line, situationLabel: situation.label)
            }
        }

        ForEach(SituationGroup.allCases, id: \.self) { group in
            let sits = content.situations.filter { $0.group == group }
            if !sits.isEmpty {
                MyTurnSectionLabel(text: group.title)
                    .padding(.top, 12)
                ForEach(sits) { s in
                    Button {
                        store.sayThisSituationId = s.id
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        MyTurnRow(title: s.label, subtitle: "\(s.lines.count) lines") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.hotRose)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Level 2

    @ViewBuilder
    private func linesLevel(_ situation: Situation) -> some View {
        Button {
            store.sayThisSituationId = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("All situations")
                    .font(.jakarta(14, weight: .semiBold))
            }
            .foregroundColor(.hotRose)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)

        Text(situation.label)
            .font(.jakarta(22, weight: .bold))
            .foregroundColor(.warmWhite)
            .padding(.bottom, 4)

        if !store.hasSeenRiskExplainer {
            riskExplainer
        }

        ForEach(situation.lines) { line in
            lineRow(line, situationLabel: nil)
        }
    }

    private var riskExplainer: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Safe lines end the conversation. Bold lines make you sound like you know things, and he might ask a follow-up.")
                .font(.jakarta(13, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.8))
            Spacer(minLength: 0)
            Button {
                withAnimation { store.hasSeenRiskExplainer = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.warmWhite.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(Color.hotRose.opacity(0.12))
        .cornerRadius(12)
    }

    /// The line itself is set larger than everything else in the row: it is
    /// what gets read on a glance.
    private func lineRow(_ line: SayLine, situationLabel: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(line.risk == .bold ? Color.gold : Color.hotRose)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                if let situationLabel {
                    Text(situationLabel.uppercased())
                        .font(.feedBadge)
                        .tracking(1)
                        .foregroundColor(.textSecondaryOnCard)
                }
                Text(line.text)
                    .font(.jakarta(19, weight: .bold))
                    .foregroundColor(.textPrimaryOnCard)
                    .fixedSize(horizontal: false, vertical: true)
                Text(line.usage)
                    .font(.jakarta(13, weight: .regular))
                    .foregroundColor(.textSecondaryOnCard)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(line.risk.label.uppercased())
                        .font(.jakarta(10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(line.risk == .bold ? Color(hex: "#9A7B1A") : .hotRose)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill((line.risk == .bold ? Color.gold : Color.hotRose).opacity(0.12)))
                    if let term = line.lingo.flatMap({ lingoById[$0] }) {
                        // One tap to the phrase's Lingo entry: the saying is
                        // taught, not just quoted.
                        Button {
                            store.lingoQuery = ""
                            store.lingoExpandedId = term.id
                            withAnimation(.spring(duration: 0.25)) { store.lastModule = .lingo }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "book")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(term.term)
                                    .font(.jakarta(10, weight: .bold))
                            }
                            .foregroundColor(.textSecondaryOnCard)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().stroke(Color.textSecondaryOnCard.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("What \(term.term) means")
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                store.toggleStar(line.id)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: store.isStarred(line.id) ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(store.isStarred(line.id) ? .gold : .textSecondaryOnCard)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isStarred(line.id) ? "Remove from your lines" : "Save to your lines")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
    }
}
