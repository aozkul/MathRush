//
//  FeedbackEngine.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import UIKit

final class FeedbackEngine {

    static let shared = FeedbackEngine()

    private init() {}

    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func boss() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
    }

    func combo() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
