import SwiftUI

struct TeamPageRivalryMeter: View {
    let intensity: Double

    private var contextLine: String {
        if intensity >= 0.8 { return "Derby incoming. Tread carefully." }
        if intensity >= 0.5 { return "One to watch coming up." }
        return "Nothing brewing right now."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Labels
            HStack {
                Text("Mild")
                    .font(.jakarta(11, weight: .medium))
                    .foregroundColor(.warmWhite.opacity(0.5))
                Spacer()
                Text("Intense")
                    .font(.jakarta(11, weight: .medium))
                    .foregroundColor(.warmWhite.opacity(0.5))
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.warmWhite.opacity(0.2))
                        .frame(height: 6)

                    // Fill
                    Capsule()
                        .fill(Color.hotRose)
                        .frame(width: max(6, geo.size.width * intensity), height: 6)

                    // Marker dot
                    Circle()
                        .fill(Color.hotRose)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, geo.size.width * intensity - 6))
                }
            }
            .frame(height: 12)

            // Context line
            Text(contextLine)
                .font(.jakarta(13, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.7))
        }
        .padding(.top, 8)
    }
}
