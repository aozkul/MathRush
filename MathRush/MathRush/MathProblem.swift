//
//  MathProblem.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

struct MathProblem {

    let question: String
    let correctAnswer: Int
    let shownAnswer: Int
    let isShownAnswerCorrect: Bool

    static func generate(isBoss: Bool) -> MathProblem {

        let a = Int.random(in: isBoss ? 20...99 : 10...50)
        let b = Int.random(in: 2...9)

        let op = ["+", "-", "×"].randomElement()!

        var correct = 0

        switch op {
        case "+": correct = a + b
        case "-": correct = a - b
        default: correct = a * b
        }

        let showCorrect = Bool.random()

        let shown = showCorrect
            ? correct
            : correct + Int.random(in: -10...10)

        return MathProblem(
            question: "\(a) \(op) \(b)",
            correctAnswer: correct,
            shownAnswer: shown,
            isShownAnswerCorrect: showCorrect
        )
    }

    /// Multiplayer için deterministik üretim (aynı seed => aynı sorular)
    static func generate<R: RandomNumberGenerator>(isBoss: Bool, rng: inout R) -> MathProblem {

        let a = Int.random(in: isBoss ? 20...99 : 10...50, using: &rng)
        let b = Int.random(in: 2...9, using: &rng)

        let op = ["+", "-", "×"].randomElement(using: &rng)!

        var correct = 0

        switch op {
        case "+": correct = a + b
        case "-": correct = a - b
        default: correct = a * b
        }

        let showCorrect = Bool.random(using: &rng)

        let shown = showCorrect
            ? correct
            : correct + Int.random(in: -10...10, using: &rng)

        return MathProblem(
            question: "\(a) \(op) \(b)",
            correctAnswer: correct,
            shownAnswer: shown,
            isShownAnswerCorrect: showCorrect
        )
    }
}
