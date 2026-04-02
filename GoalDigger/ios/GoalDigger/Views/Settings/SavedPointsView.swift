import SwiftUI

struct SavedPointsView: View {
    @State private var points: [String] = []

    var body: some View {
        Group {
            if points.isEmpty {
                VStack(spacing: Theme.sectionSpacing) {
                    Spacer()
                    Image(systemName: "heart")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textTertiary)
                    Text("No saved talking points yet")
                        .font(Theme.feedHeadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Tap the heart on any talking point\nto save it for later.")
                        .font(Theme.onboardingBody)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.cardSpacing) {
                        ForEach(points, id: \.self) { point in
                            SavedPointRow(
                                text: point,
                                onRemove: {
                                    withAnimation {
                                        SavedPointsService.shared.remove(point)
                                        points = SavedPointsService.shared.savedPoints
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.top, Theme.elementSpacing)
                }
            }
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Saved")
        .onAppear {
            points = SavedPointsService.shared.savedPoints
        }
    }
}

private struct SavedPointRow: View {
    let text: String
    let onRemove: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(Theme.talkingPointText)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 14) {
                Button {
                    onRemove()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 11))
                        Text("Remove")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    UIPasteboard.general.string = text
                    copied = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(copied ? Theme.accentGreen : Theme.textTertiary)
                }
                .buttonStyle(.plain)

                ShareLink(item: "\(text)\n\n— via Goal Digger") {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("Share")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}
