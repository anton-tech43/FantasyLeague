import SwiftUI

struct GoalDiggerWordmark: View {
    var size: Font = .jakarta(28, weight: .bold)

    var body: some View {
        HStack(spacing: 0) {
            Text("Goal")
                .font(size)
                .foregroundColor(.warmWhite)
            Text("Digger")
                .font(size)
                .foregroundColor(.hotRose)
        }
    }
}
