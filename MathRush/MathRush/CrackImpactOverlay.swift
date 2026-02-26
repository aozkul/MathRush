//
//  CrackImpactOverlay.swift
//  MathRush
//
//  Created by Ali Ozkul on 26.02.26.
//

import SwiftUI

/// "Impact" that can cause cracking: shockwave ring + brief flash + edge sparks.
/// Designed to be short-lived (≈200ms).
struct CrackImpactOverlay: View {
    let cornerRadius: CGFloat
    let band: CGFloat // edge band thickness in px (so center stays clean)

    @State private var t: CGFloat = 0

    var body: some View {
        ZStack {
            // Quick flash (screen)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.22 * (1 - t)))
                .blendMode(.screen)
                .opacity(t < 0.9 ? 1 : 0)

            // Shockwave ring (centered) but masked to edges so text stays clean
            GeometryReader { geo in
                let size = geo.size
                let r = min(size.width, size.height) * (0.25 + 0.75 * t) // grows fast

                Circle()
                    .strokeBorder(Color.white.opacity(0.65 * (1 - t)),
                                  lineWidth: 2.0 + 6.0 * (1 - t))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: size.width * 0.5, y: size.height * 0.5)
                    .blendMode(.screen)
                    .mask(edgeRingMask(in: size))
            }

            // Edge sparks
            Canvas { ctx, size in
                ctx.blendMode = .screen

                // mask to edges ring
                let rect = CGRect(origin: .zero, size: size)
                let outer = Path(roundedRect: rect, cornerRadius: cornerRadius)
                let innerRect = rect.insetBy(dx: band, dy: band)
                let inner = Path(roundedRect: innerRect, cornerRadius: max(0, cornerRadius - band))

                var ring = outer
                ring.addPath(inner)
                ctx.clip(to: ring, style: .init(eoFill: true))

                // sparks fade with t
                let alpha = CGFloat(max(0, 1 - t))
                guard alpha > 0.01 else { return }

                var rng = SeededRNG(seed: UInt64(Int(t * 10_000) ^ 0xABCDEF))

                let sparks = 10
                for _ in 0..<sparks {
                    let p = randomPointNearEdge(in: rect, inset: band * 0.25, rng: &rng)
                    let len = (8 + 28 * CGFloat(rng.nextDouble())) * alpha
                    let a = CGFloat(rng.nextDouble()) * .pi * 2

                    var path = Path()
                    path.move(to: p)
                    path.addLine(to: CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len))

                    ctx.stroke(path,
                               with: .color(.white.opacity(0.55 * alpha)),
                               style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                }
            }
            .opacity(1 - t)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.20)) {
                t = 1
            }
        }
    }

    private func edgeRingMask(in size: CGSize) -> some View {
        let rect = CGRect(origin: .zero, size: size)
        let outer = RoundedRectangle(cornerRadius: cornerRadius)
        let innerRect = rect.insetBy(dx: band, dy: band)
        let inner = RoundedRectangle(cornerRadius: max(0, cornerRadius - band))
            .frame(width: innerRect.width, height: innerRect.height)
            .position(x: rect.midX, y: rect.midY)

        return ZStack {
            outer
            inner.blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private func randomPointNearEdge(in rect: CGRect, inset: CGFloat, rng: inout SeededRNG) -> CGPoint {
        let side = Int(rng.next() % 4)
        let xMin = rect.minX + inset
        let xMax = rect.maxX - inset
        let yMin = rect.minY + inset
        let yMax = rect.maxY - inset

        func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * min(1, max(0, t)) }

        switch side {
        case 0: return CGPoint(x: lerp(xMin, xMax, CGFloat(rng.nextDouble())), y: yMin)
        case 1: return CGPoint(x: xMax, y: lerp(yMin, yMax, CGFloat(rng.nextDouble())))
        case 2: return CGPoint(x: lerp(xMin, xMax, CGFloat(rng.nextDouble())), y: yMax)
        default: return CGPoint(x: xMin, y: lerp(yMin, yMax, CGFloat(rng.nextDouble())))
        }
    }
}
