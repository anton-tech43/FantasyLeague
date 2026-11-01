import SwiftUI

/// The last five league results as lettered dots, newest on the left. Plain
/// dots were unreadable to all six personas (council TEAM-01-58).
///
/// `recent_form` comes newest first: checked against the dated league results
/// on four cached pages (Arsenal, Liverpool, Newcastle, Man Utd, 2026-11-01),
/// so it is drawn as it comes.
struct TeamPageFormDots: View {
    let recentForm: String

    /// The results in drawing order, anything but W/D/L dropped.
    static func results(_ recentForm: String) -> [Character] {
        recentForm.uppercased().filter { "WDL".contains($0) }.map { $0 }
    }

    var body: some View {
        let results = Self.results(recentForm)
        HStack(spacing: 5) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                Text(String(result))
                    .font(.jakarta(11, weight: .bold))
                    .foregroundColor(result == "D" ? .deepMauve : .warmWhite)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(color(result)))
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last \(results.count) league games, newest first: "
            + results.map { $0 == "W" ? "won" : $0 == "L" ? "lost" : "drew" }.joined(separator: ", "))
    }

    private func color(_ result: Character) -> Color {
        switch result {
        case "W": return .hotRose
        case "L": return Color.red.opacity(0.6)
        default:  return .softBlush
        }
    }
}
