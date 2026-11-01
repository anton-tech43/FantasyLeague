import SwiftUI

/// Shimmer skeleton matching ImmersiveCard dimensions (65/35 zone split).
/// Shown during initial feed load before content arrives.
struct ImmersiveSkeletonCard: View {
    let cardHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Zone 1 skeleton (65%)
            Color.deepMauve
                .shimmering(opacity: 0.08)
                .frame(height: cardHeight * Layout.immersiveZone1Ratio)
                .overlay(
                    Rectangle()
                        .stroke(Color.hotRose, lineWidth: 3)
                        .padding(1.5)
                )

            // Zone 2 skeleton (35%)
            Color.hotRose
                .shimmering(opacity: 0.10)
                .frame(height: cardHeight * Layout.immersiveZone2Ratio)
        }
        .frame(height: cardHeight)
        .clipped()
    }
}

/// A grey bar standing in for a line of text while a page loads.
struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        Capsule()
            .fill(Color.shimmer)
            .shimmering()
            .clipShape(Capsule())
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
    }
}

extension View {
    /// A soft light sweeping across, so a skeleton reads as "on its way"
    /// rather than empty. Still under Reduce Motion.
    func shimmering(opacity: Double = 0.08) -> some View {
        modifier(Shimmer(opacity: opacity))
    }

    /// Hides a skeleton's shapes from VoiceOver and says "Loading" once.
    func loadingSkeleton() -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
    }
}

private struct Shimmer: ViewModifier {
    let opacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        Color.warmWhite.opacity(opacity)
                            .frame(width: geo.size.width * 0.4)
                            .blur(radius: 30)
                            .offset(x: geo.size.width * offset)
                    }
                    .clipped()
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            offset = 1.0
                        }
                    }
                }
            }
    }
}
