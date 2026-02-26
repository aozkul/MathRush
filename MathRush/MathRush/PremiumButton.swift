//
//  PremiumButton.swift
//  MathRush
//
//  Created by Ali Ozkul on 25.02.26.
//

import SwiftUI

struct PremiumRoundButton: View {

    var icon: String
    var color: Color
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 90, height: 90)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.95),
                                    color.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: color.opacity(0.6), radius: 14)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 2)
                )
                .scaleEffect(pressed ? 0.9 : 1)
                .animation(.spring(response: 0.25), value: pressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}
