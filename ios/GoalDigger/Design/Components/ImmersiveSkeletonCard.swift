import SwiftUI

/// Shimmer skeleton matching ImmersiveCard dimensions (65/35 zone split).
/// Shown during initial feed load before content arrives.
struct ImmersiveSkeletonCard: View {
    let cardHeight: CGFloat

    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        VStack(spacing: 0) {
            // Zone 1 skeleton (65%)
            ZStack {
                Color.deepMauve
                shimmerOverlay(opacity: 0.08)
            }
            .frame(height: cardHeight * Layout.immersiveZone1Ratio)
            .overlay(
                Rectangle()
                    .stroke(Color.hotRose, lineWidth: 3)
                    .padding(1.5)
            )

            // Zone 2 skeleton (35%)
            ZStack {
                Color.hotRose
                shimmerOverlay(opacity: 0.10)
            }
            .frame(height: cardHeight * Layout.immersiveZone2Ratio)
        }
        .frame(height: cardHeight)
        .clipped()
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.0
            }
        }
    }

    private func shimmerOverlay(opacity: Double) -> some View {
        GeometryReader { geo in
            Color.warmWhite.opacity(opacity)
                .frame(width: geo.size.width * 0.4)
                .blur(radius: 30)
                .offset(x: geo.size.width * shimmerOffset)
        }
        .clipped()
    }
}
