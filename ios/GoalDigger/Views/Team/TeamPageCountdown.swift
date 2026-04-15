import SwiftUI

struct TeamPageCountdown: View {
    let targetDate: String
    @State private var isPulsing = false

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var target: Date? {
        Self.isoFormatter.date(from: targetDate)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let target {
                let remaining = target.timeIntervalSince(context.date)
                countdownText(remaining: remaining)
            }
        }
    }

    @ViewBuilder
    private func countdownText(remaining: TimeInterval) -> some View {
        if remaining <= 0 {
            Text("LIVE NOW")
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.hotRose)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            Text("\(minutes) minute\(minutes == 1 ? "" : "s") until kickoff")
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.hotRose)
        } else if remaining < 86400 {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            Text("\(hours)h \(minutes)m until kickoff")
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.hotRose)
        } else {
            let days = Int(remaining / 86400)
            let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
            Text("\(days) day\(days == 1 ? "" : "s") \(hours) hour\(hours == 1 ? "" : "s") until kickoff")
                .font(.jakarta(17, weight: .bold))
                .foregroundColor(.hotRose)
        }
    }
}
