import SwiftUI

/// Renders a body of news copy as plain text with glossary-matched terms
/// underlined and tappable. Tapping opens a small popover with the
/// explanation. Untagged words render normally.
///
/// Implementation: builds an `AttributedString` with `.link` attributes on
/// matched ranges and routes those links through the `openURL` environment
/// to a local popover rather than the system browser. Uses a custom
/// `goaldigger://glossary?term=...` scheme so the system never tries to
/// open the URL externally.
///
/// Matching is case-insensitive with word-boundary checks: "brace" matches
/// the word "brace" but not "bracelet". Overlapping matches keep the
/// earliest match.
struct GlossaryText: View {
    let raw: String

    @State private var activeTerm: GlossaryTerm?

    var body: some View {
        Text(attributedBody)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "goaldigger",
                      url.host == "glossary",
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let id = components.queryItems?.first(where: { $0.name == "term" })?.value,
                      let term = GlossaryService.shared.lookup(id: id) else {
                    return .systemAction
                }
                activeTerm = term
                return .handled
            })
            // Custom bottom sheet instead of the system popover. The popover's
            // bubble + system chrome was off-brand and the dark-on-dark
            // default colours rendered the explanation invisible. The sheet
            // is styled to the app's dark + hot-rose language: deep mauve
            // background, vertical rose accent bar, warm-white text. Sized
            // tight to the content so it doesn't feel like a full-screen
            // modal; swipe-down dismisses.
            .sheet(item: $activeTerm) { term in
                GlossaryTermSheet(term: term)
                    .presentationDetents([.height(220), .medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.deepMauve)
            }
    }

    /// Build an AttributedString with matched glossary ranges underlined and
    /// linked. The link URL encodes the term id so `openURL` can route back
    /// to the right popover.
    private var attributedBody: AttributedString {
        let matches = findMatches(in: raw, against: GlossaryService.shared.terms)
        guard !matches.isEmpty else {
            return AttributedString(raw)
        }

        var result = AttributedString()
        var cursor = raw.startIndex
        for (range, termID) in matches {
            if cursor < range.lowerBound {
                result += AttributedString(String(raw[cursor..<range.lowerBound]))
            }
            var matched = AttributedString(String(raw[range]))
            matched.underlineStyle = .single
            // hot rose works on both dark mauve body backgrounds and blush cards.
            matched.foregroundColor = .hotRose
            if let encoded = termID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "goaldigger://glossary?term=\(encoded)") {
                matched.link = url
            }
            result += matched
            cursor = range.upperBound
        }
        if cursor < raw.endIndex {
            result += AttributedString(String(raw[cursor..<raw.endIndex]))
        }
        return result
    }

    /// Scans the raw string for every glossary term and alias, returns a
    /// sorted, non-overlapping list of (range, termID) tuples.
    private func findMatches(in raw: String, against terms: [GlossaryTerm]) -> [(Range<String.Index>, String)] {
        var matches: [(Range<String.Index>, String)] = []
        for term in terms {
            let candidates = [term.term] + term.aliases
            for candidate in candidates where !candidate.isEmpty {
                var searchIndex = raw.startIndex
                while let range = raw.range(of: candidate, options: .caseInsensitive, range: searchIndex..<raw.endIndex) {
                    if hasWordBoundary(at: range, in: raw) {
                        matches.append((range, term.id))
                    }
                    searchIndex = range.upperBound
                }
            }
        }
        matches.sort { $0.0.lowerBound < $1.0.lowerBound }
        var deduped: [(Range<String.Index>, String)] = []
        for m in matches {
            if let last = deduped.last, m.0.lowerBound < last.0.upperBound { continue }
            deduped.append(m)
        }
        return deduped
    }

    /// Word-boundary check: the character immediately before and after the
    /// match must not be a letter. Prevents "brace" matching inside
    /// "bracelet". Hyphens are treated as letters so "hat-trick" survives
    /// boundary checks when the alias is "hattrick".
    private func hasWordBoundary(at range: Range<String.Index>, in raw: String) -> Bool {
        let prevIsLetter: Bool = range.lowerBound == raw.startIndex
            ? false
            : raw[raw.index(before: range.lowerBound)].isLetter
        let nextIsLetter: Bool = range.upperBound == raw.endIndex
            ? false
            : raw[range.upperBound].isLetter
        return !prevIsLetter && !nextIsLetter
    }
}

/// Bottom-sheet content for an active glossary term. Uses the app's dark
/// theme — deep mauve background (set on the presentation), vertical rose
/// accent bar on the left, warm-white text. No bubble, no system chrome.
private struct GlossaryTermSheet: View {
    let term: GlossaryTerm

    /// Display the term with its first letter capitalised, preserving any
    /// existing casing (so "VAR" / "xG" / "Champions League" stay intact
    /// instead of becoming "Var" / "Xg" / "Champions league").
    private var displayTerm: String {
        guard let first = term.term.first else { return term.term }
        return String(first).uppercased() + term.term.dropFirst()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Vertical rose accent bar — same visual motif as TalkingPointCard
            // and the matchday post-match sections. Anchors the sheet to the
            // GoalDigger card language.
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.hotRose)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 10) {
                Text("GLOSSARY")
                    .font(.sectionHeader)
                    .tracking(1.5)
                    .foregroundColor(.hotRose)

                Text(displayTerm)
                    .font(.jakarta(22, weight: .bold))
                    .foregroundColor(.textOnDark)

                Text(term.explanation)
                    .font(.onboardingBody)
                    .foregroundColor(.textOnDark.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.screenPadding)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
