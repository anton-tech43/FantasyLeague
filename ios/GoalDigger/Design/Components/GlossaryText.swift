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
            .popover(item: $activeTerm) { term in
                VStack(alignment: .leading, spacing: 8) {
                    Text(term.term.capitalized)
                        .font(.feedHeadline)
                        .foregroundColor(.textPrimaryOnCard)
                    Text(term.explanation)
                        .font(.onboardingBody)
                        .foregroundColor(.textPrimaryOnCard)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: 280)
                // Force a light blush background under the popover so the
                // charcoal text is legible. Without this, the popover
                // inherits the app's preferredColorScheme(.dark) and renders
                // dark-on-dark — the term explanation is unreadable. We also
                // disable iOS's auto-tinting of popover chrome so the system
                // arrow/balloon picks up our colour.
                .background(Color.cardBackground)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color.cardBackground)
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
