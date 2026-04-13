import SwiftUI

struct ProgressDotsView: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.hotRose : Color.mutedText.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
