import SwiftUI

/// Shimmer skeleton matching ImmersiveCard dimensions (75/25 zone split).
/// Shown during initial feed load before content arrives.
struct ImmersiveSkeletonCard: View {
    let cardHeight: CGFloat

    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        VStack(spacing: 0) {
            // Zone 1 skeleton (75%) — 3-sided rose border (open at bottom)
            ZStack {
                Color.deepMauve
                shimmerOverlay(opacity: 0.08)
            }
            .frame(height: cardHeight * 0.75)
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        let inset: CGFloat = 2.5
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: inset, y: h))
                        path.addLine(to: CGPoint(x: inset, y: inset))
                        path.addLine(to: CGPoint(x: w - inset, y: inset))
                        path.addLine(to: CGPoint(x: w - inset, y: h))
                    }
                    .stroke(Color.hotRose, lineWidth: 5)
                }
            )

            // Zone 2 skeleton (25%)
            ZStack {
                Color.hotRose
                shimmerOverlay(opacity: 0.10)
            }
            .frame(height: cardHeight * 0.25)
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
