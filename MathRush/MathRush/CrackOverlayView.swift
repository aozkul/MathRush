//
//  CrackOverlayView.swift
//  MathRush
//
//  Created by Ali Ozkul on 26.02.26.
//

import SwiftUI

/// Procedural "glass crack" overlay that draws cracks ONLY near the edges,
/// keeping the center (question text) clean.
///
/// - level: 0...1 (crack intensity)
/// - seed: changes the pattern each trigger
/// - cornerRadius: match your card radius
struct CrackOverlayView: View {
    let level: CGFloat
    let seed: Int
    let cornerRadius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            guard level > 0.01 else { return }

            let rect = CGRect(origin: .zero, size: size)

            // 1) Clip to rounded card
            let cardClip = Path(roundedRect: rect, cornerRadius: cornerRadius)
            ctx.clip(to: cardClip)

            // 2) Clip again to ONLY draw in an "edge ring" (outer - inner)
            let band = min(size.width, size.height) * (0.10 + 0.06 * level) // ~10-16%
            let outer = Path(roundedRect: rect, cornerRadius: cornerRadius)
            let innerRect = rect.insetBy(dx: band, dy: band)
            let inner = Path(roundedRect: innerRect, cornerRadius: max(0, cornerRadius - band))

            var ring = outer
            ring.addPath(inner)
            ctx.clip(to: ring, style: .init(eoFill: true)) // even-odd => only the ring area

            // Crack count increases with level
            let crackCount = max(1, Int((level * 10).rounded(.up)))

            var rng = SeededRNG(seed: UInt64(seed))

            for _ in 0..<crackCount {
                // Start near edges
                let start = randomPointNearEdge(in: rect, inset: band * 0.4, rng: &rng)

                // Aim roughly towards center, with small random deviation
                let angleToCenter = atan2(rect.midY - start.y, rect.midX - start.x)
                let angle = angleToCenter + CGFloat(rng.nextDouble() - 0.5) * 0.9

                let length = lerp(120, 520, CGFloat(rng.nextDouble())) * (0.30 + level)

                let path = makeCrackPath(
                    start: jitter(start, amount: 8 * level, rng: &rng),
                    angle: angle,
                    length: length,
                    segments: Int(lerp(5, 14, level)),
                    jaggedness: lerp(8, 22, level),
                    rng: &rng
                )

                // 1) dark depth stroke (layer-scoped filter)
                ctx.drawLayer { layer in
                    layer.addFilter(.shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1))
                    layer.stroke(
                        path,
                        with: .color(.black.opacity(lerp(0.18, 0.34, level))),
                        style: StrokeStyle(lineWidth: lerp(1.1, 2.3, level), lineCap: .round, lineJoin: .round)
                    )
                }

                // 2) bright glass stroke (screen blend, layer-scoped)
                ctx.drawLayer { layer in
                    layer.blendMode = .screen
                    layer.addFilter(.shadow(color: .white.opacity(0.35), radius: 6, x: 0, y: 0))
                    layer.stroke(
                        path,
                        with: .color(.white.opacity(lerp(0.20, 0.72, level))),
                        style: StrokeStyle(lineWidth: lerp(0.7, 1.5, level), lineCap: .round, lineJoin: .round)
                    )
                }

                // 3) micro-branches (also in edge ring due to clipping)
                if level > 0.25 {
                    let branches = Int(lerp(0, 3, level))
                    for _ in 0..<branches {
                        // pick a point near the start region (simple + stable)
                        let p = jitter(start, amount: 16 * level, rng: &rng)
                        let bAngle = angle + CGFloat(rng.nextDouble() - 0.5) * 1.2
                        let bLen = length * lerp(0.12, 0.28, CGFloat(rng.nextDouble())) * level

                        let bPath = makeCrackPath(
                            start: p,
                            angle: bAngle,
                            length: bLen,
                            segments: Int(lerp(3, 7, level)),
                            jaggedness: lerp(6, 16, level),
                            rng: &rng
                        )

                        ctx.drawLayer { layer in
                            layer.blendMode = .screen
                            layer.stroke(
                                bPath,
                                with: .color(.white.opacity(lerp(0.10, 0.40, level))),
                                style: StrokeStyle(lineWidth: lerp(0.5, 1.0, level), lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
            }

            // subtle glass dust sparkle (still only edges because of ring clip)
            if level > 0.2 {
                let dustCount = Int(lerp(0, 70, level))
                for _ in 0..<dustCount {
                    let x = CGFloat(rng.nextDouble()) * size.width
                    let y = CGFloat(rng.nextDouble()) * size.height
                    let r = CGFloat(rng.nextDouble()) * lerp(0.6, 1.8, level)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(lerp(0.0, 0.08, level)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Crack Geometry

    private func makeCrackPath(
        start: CGPoint,
        angle: CGFloat,
        length: CGFloat,
        segments: Int,
        jaggedness: CGFloat,
        rng: inout SeededRNG
    ) -> Path {
        var p = Path()
        p.move(to: start)

        var current = start
        let step = length / CGFloat(max(segments, 1))

        for s in 1...segments {
            let t = CGFloat(s) / CGFloat(segments)
            let base = CGPoint(
                x: start.x + cos(angle) * step * CGFloat(s),
                y: start.y + sin(angle) * step * CGFloat(s)
            )

            // perpendicular for jagged zig-zag
            let perp = CGPoint(x: -sin(angle), y: cos(angle))
            let wiggle = (CGFloat(rng.nextDouble() - 0.5) * 2) * jaggedness * (0.25 + t)
            let next = CGPoint(x: base.x + perp.x * wiggle, y: base.y + perp.y * wiggle)

            // small kink
            let kink = CGFloat(rng.nextDouble() - 0.5) * jaggedness * 0.35
            let kinked = CGPoint(x: next.x + perp.x * kink, y: next.y + perp.y * kink)

            p.addLine(to: kinked)
            current = kinked
        }

        // tiny split at the end
        if length > 220, rng.nextDouble() > 0.35 {
            let branchAngle = angle + CGFloat(rng.nextDouble() - 0.5) * 0.9
            let branchLen = length * 0.18
            p.addLine(to: CGPoint(x: current.x + cos(branchAngle) * branchLen,
                                  y: current.y + sin(branchAngle) * branchLen))
        }

        return p
    }

    private func jitter(_ p: CGPoint, amount: CGFloat, rng: inout SeededRNG) -> CGPoint {
        CGPoint(
            x: p.x + (CGFloat(rng.nextDouble() - 0.5) * 2) * amount,
            y: p.y + (CGFloat(rng.nextDouble() - 0.5) * 2) * amount
        )
    }

    private func randomPointNearEdge(in rect: CGRect, inset: CGFloat, rng: inout SeededRNG) -> CGPoint {
        // 0: top, 1: right, 2: bottom, 3: left
        let side = Int(rng.next() % 4)

        let xMin = rect.minX + inset
        let xMax = rect.maxX - inset
        let yMin = rect.minY + inset
        let yMax = rect.maxY - inset

        switch side {
        case 0: // top
            return CGPoint(x: lerp(xMin, xMax, CGFloat(rng.nextDouble())), y: yMin)
        case 1: // right
            return CGPoint(x: xMax, y: lerp(yMin, yMax, CGFloat(rng.nextDouble())))
        case 2: // bottom
            return CGPoint(x: lerp(xMin, xMax, CGFloat(rng.nextDouble())), y: yMax)
        default: // left
            return CGPoint(x: xMin, y: lerp(yMin, yMax, CGFloat(rng.nextDouble())))
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(1, max(0, t))
    }
}

/// Deterministic random generator (stable across runs for same seed)
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        let v = next() >> 11
        return Double(v) / Double(1 << 53)
    }
}
