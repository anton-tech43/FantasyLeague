import SwiftUI

/// A home kit drawn from colour + pattern, on one shared silhouette.
///
/// The spec's hard rule for the Kits deck is that all twenty shirts sit on
/// exactly the same template, so she learns colours and patterns rather than
/// a drawing style. Drawing it in code guarantees that, and a sponsor change
/// costs nobody a redraw.
struct KitView: View {
    let spec: KitSpec

    private var primary: Color { Color(hex: spec.primary) }
    private var secondary: Color { Color(hex: spec.secondary) }
    private var shorts: Color { Color(hex: spec.shorts ?? "#FFFFFF") }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let shirtH = h * 0.62
            ZStack(alignment: .top) {
                // Shirt body + pattern, clipped to the silhouette.
                ZStack {
                    primary
                    pattern(width: w, height: shirtH)
                }
                .frame(width: w, height: shirtH)
                .clipShape(ShirtShape())
                .overlay(ShirtShape().stroke(Color.black.opacity(0.18), lineWidth: 1.5))

                // Collar.
                CollarShape()
                    .fill(secondary)
                    .frame(width: w * 0.22, height: shirtH * 0.14)
                    .offset(y: shirtH * 0.02)

                // Shorts.
                ShortsShape()
                    .fill(shorts)
                    .overlay(ShortsShape().stroke(Color.black.opacity(0.18), lineWidth: 1.5))
                    .frame(width: w * 0.58, height: h * 0.30)
                    .offset(y: shirtH - 2)
            }
            .frame(width: w, height: h, alignment: .top)
        }
        .aspectRatio(0.9, contentMode: .fit)
    }

    @ViewBuilder
    private func pattern(width w: CGFloat, height h: CGFloat) -> some View {
        switch spec.pattern {
        case .plain:
            EmptyView()
        case .stripes:
            HStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { i in
                    (i.isMultiple(of: 2) ? primary : secondary)
                }
            }
        case .pinstripes:
            HStack(spacing: w * 0.07) {
                ForEach(0..<8, id: \.self) { _ in
                    secondary.frame(width: 2)
                }
            }
        case .hoops:
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    (i.isMultiple(of: 2) ? primary : secondary)
                }
            }
        case .halves:
            HStack(spacing: 0) {
                primary
                secondary
            }
        case .quarters:
            VStack(spacing: 0) {
                HStack(spacing: 0) { primary; secondary }
                HStack(spacing: 0) { secondary; primary }
            }
        case .sash:
            secondary
                .frame(width: w * 0.18, height: h * 1.6)
                .rotationEffect(.degrees(35))
        case .sleeves:
            // The sleeves take the secondary colour: Arsenal, Villa, Ipswich.
            HStack(spacing: 0) {
                secondary.frame(width: w * 0.24)
                primary
                secondary.frame(width: w * 0.24)
            }
        }
    }
}

/// Body with two short sleeves. Coordinates as fractions of the frame.
struct ShirtShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: w * 0.36, y: 0))                 // left shoulder / collar start
        p.addLine(to: CGPoint(x: w * 0.64, y: 0))              // right collar
        p.addLine(to: CGPoint(x: w * 1.00, y: h * 0.22))       // right sleeve tip
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.42))       // sleeve hem
        p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.36))       // underarm
        p.addLine(to: CGPoint(x: w * 0.76, y: h))              // right hem
        p.addLine(to: CGPoint(x: w * 0.24, y: h))              // left hem
        p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.36))       // underarm
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.42))       // sleeve hem
        p.addLine(to: CGPoint(x: 0, y: h * 0.22))              // left sleeve tip
        p.closeSubpath()
        return p
    }
}

struct CollarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: r.width, y: 0), control: CGPoint(x: r.width / 2, y: r.height * 1.8))
        p.closeSubpath()
        return p
    }
}

struct ShortsShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w * 1.04, y: h))
        p.addLine(to: CGPoint(x: w * 0.58, y: h))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.42, y: h))
        p.addLine(to: CGPoint(x: -w * 0.04, y: h))
        p.closeSubpath()
        return p
    }
}
