//
//  ConfettiView.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import SwiftUI

struct ConfettiView: View {

    @Binding var show: Bool

    var body: some View {
        GeometryReader { geo in
            if show {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        let center = CGPoint(x: size.width / 2,
                                             y: size.height * 0.35)

                        for i in 0..<40 {
                            var symbol = ctx.resolve(
                                Text("■")
                                    .font(.system(size: CGFloat.random(in: 10...16)))
                                    .foregroundStyle(randomColor())
                            )

                            let angle = Double(i) * 0.15
                            let radius = Double(timeline.date.timeIntervalSinceReferenceDate * 120)
                            let x = center.x + cos(angle) * radius
                            let y = center.y + sin(angle) * radius + Double(i)

                            ctx.draw(symbol, at: CGPoint(x: x, y: y))
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        show = false
                    }
                }
            }
        }
    }

    private func randomColor() -> Color {
        [.cyan, .pink, .yellow, .orange, .green, .purple, .white].randomElement()!
    }
}
