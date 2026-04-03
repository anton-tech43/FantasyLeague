import SwiftUI

// MARK: - SavedPointsView
// Displays saved talking points with copy, share, and remove actions.
//
// Design decisions for other agents:
// - Accessed from Settings → "Saved talking points"
// - Each point has copy, share, and remove actions
// - Empty state with guidance text
// - Plain text only for clipboard (security)

struct SavedPointsView: View {
    @State private var points: [String] = []

    var body: some View {
        Group {
            if points.isEmpty {
                emptyState
            } else {
                pointsList
            }
        }
        .navigationTitle("Saved Points")
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear {
            points = SavedPointsService.shared.savedPoints
        }
    }

    // MARK: - Points List

    private var pointsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.elementSpacing) {
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            Image(systemName: "bookmark")
                .font(.system(size: 50))
                .foregroundStyle(Theme.textTertiary)

            Text("No saved points yet")
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textSecondary)

            Text("Tap the bookmark icon on any talking point to save it here for later.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Spacer()
        }
    }
}

// MARK: - Saved Point Row

private struct SavedPointRow: View {
    let text: String
    let onRemove: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(text)
                    .font(Theme.talkingPointText)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    // Share
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    // Remove
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(14)

            if copied {
                Text("Copied!")
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.accentGreen)
                    .transition(.opacity)
                    .padding(.bottom, 8)
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.dustyRose.opacity(0.4), lineWidth: 1)
        )
        .onTapGesture {
            UIPasteboard.general.string = text
            withAnimation { copied = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { copied = false }
            }
        }
    }
}
