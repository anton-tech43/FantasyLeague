import SwiftUI

struct TeamPageFormDots: View {
    let recentForm: String
    let isExpanded: Bool
    @State private var appeared: [Bool] = []

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(recentForm.enumerated()), id: \.offset) { index, char in
                Circle()
                    .fill(dotColor(for: char))
                    .frame(width: 8, height: 8)
                    .opacity(dotVisible(at: index) ? 1 : 0)
                    .scaleEffect(dotVisible(at: index) ? 1 : 0.3)
                    .animation(
                        .spring(duration: 0.3).delay(Double(index) * 0.08),
                        value: appeared
                    )
            }
            Spacer()
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                appeared = Array(repeating: false, count: recentForm.count)
                // Trigger staggered appearance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = Array(repeating: true, count: recentForm.count)
                }
            } else {
                appeared = []
            }
        }
        .onAppear {
            if isExpanded {
                appeared = Array(repeating: true, count: recentForm.count)
            }
        }
    }

    private func dotVisible(at index: Int) -> Bool {
        guard index < appeared.count else { return !isExpanded }
        return appeared[index]
    }

    private func dotColor(for result: Character) -> Color {
        switch result {
        case "W": return .hotRose
        case "D": return .mutedText
        case "L": return Color.red.opacity(0.6)
        default: return .mutedText.opacity(0.3)
        }
    }
}
