//
//  GameViewModel.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    init() {
        print("✅ GameViewModel INIT")
    }

    // MARK: Published State
    @Published var problem: MathProblem?
    @Published var score: Int = 0
    @Published var isGameOver = false
    @Published var canContinueWithAd: Bool = false
    @Published var feedback: FeedbackType?

    @Published var comboCount: Int = 0
    @Published var comboLabel: String = "x1"

    @Published var isRushMode = false
    @Published var isBossQuestion = false

    @Published var lastPointsGained = 0

    // Multiplayer UI
    @Published var isMultiplayer: Bool = false
    @Published var opponentScore: Int = 0
    @Published var matchRemainingSeconds: Int = 0

    // MARK: Timer (Question)
    private var questionStartTime = Date()
    private var allowedSeconds: Double = 5

    // MARK: Reward-Continue Snapshot (Single Player only)
    private var continueSnapshotProblem: MathProblem?
    private var continueSnapshotRemaining: Double = 0
    private var continueSnapshotAllowed: Double = 0

    // ✅ NEW: score + combo snapshot (resume sonrası sıfırlanmasın)
    private var continueSnapshotScore: Int = 0
    private var continueSnapshotComboCount: Int = 0
    private var continueSnapshotComboLabel: String = "x1"
    private var continueSnapshotLastPoints: Int = 0

    // MARK: Match (Multiplayer)
    private var matchEndTime: Date?
    private var multiplayer: MultiplayerCoordinator?

    // MARK: RNG (Multiplayer determinism)
    private var rng: SeededRandomGenerator?

    // MARK: - Public API

    func startSinglePlayer() {
        isMultiplayer = false
        matchEndTime = nil
        multiplayer = nil
        rng = nil
        resetRun()
        generateProblem()
    }

    func startMultiplayer(coordinator: MultiplayerCoordinator, seed: Int, startAtEpoch: TimeInterval, durationSeconds: Int) {
        isMultiplayer = true
        multiplayer = coordinator

        // Aynı seed => iki cihazda aynı soru dizisi
        rng = SeededRandomGenerator(seed: UInt64(seed))

        resetRun()

        let startDate = Date(timeIntervalSince1970: startAtEpoch)
        matchEndTime = startDate.addingTimeInterval(TimeInterval(durationSeconds))
        matchRemainingSeconds = durationSeconds

        // Başlangıcı aynı anda yapmak için: startDate'e kadar bekle, sonra ilk soruyu üret
        let delay = max(0, startDate.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.generateProblem()
        }
    }

    /// GameView timer tick her geldiğinde çağır.
    func tick(now: Date) {
        guard !isGameOver else { return }

        // Multiplayer match time
        if let end = matchEndTime {
            let remaining = Int(ceil(max(0, end.timeIntervalSince(now))))
            matchRemainingSeconds = remaining

            if remaining <= 0 {
                isGameOver = true
                feedback = nil
                multiplayer?.reportScore(score)
                return
            }
        }

        // Question timeout
        if remainingSeconds(now: now) <= 0 {
            SoundEngine.shared.play("wrong")
            FeedbackEngine.shared.error()
            feedback = .wrong

            captureContinueSnapshot(now: now)

            isGameOver = true
            multiplayer?.reportScore(score)
        }
    }

    private func captureContinueSnapshot(now: Date) {
        guard !isMultiplayer else { return }
        guard !canContinueWithAd else { return } // aynı game over için bir kere al

        continueSnapshotProblem = problem
        continueSnapshotAllowed = allowedSeconds
        continueSnapshotRemaining = remainingSeconds(now: now)

        // ✅ NEW: score + combo snapshot
        continueSnapshotScore = score
        continueSnapshotComboCount = comboCount
        continueSnapshotComboLabel = comboLabel
        continueSnapshotLastPoints = lastPointsGained

        canContinueWithAd = true
    }

    func applyOpponentScore(_ value: Int) {
        opponentScore = value
    }

    func restart() {
        if isMultiplayer {
            // Multiplayer restart: yeni match başlatmak menüden olmalı (production UX)
            resetRun()
        } else {
            startSinglePlayer()
        }
    }

    // MARK: Answer Handling

    func choose(isCorrectSelected: Bool) {
        guard !isGameOver, let p = problem else { return }

        let isCorrect = p.isShownAnswerCorrect

        if isCorrectSelected == isCorrect {

            SoundEngine.shared.play("correct")
            FeedbackEngine.shared.success()

            comboCount += 1
            updateMultiplier()

            if comboCount % 5 == 0 {
                SoundEngine.shared.play("combo")
                FeedbackEngine.shared.combo()
            }

            // Boss FX (bu soruya özel flag generateProblem içinde setleniyor)
            if isBossQuestion {
                SoundEngine.shared.play("boss")
                FeedbackEngine.shared.boss()
            }

            let responseTime = Date().timeIntervalSince(questionStartTime)

            let basePoints = calculateBasePoints(problem: p)
            let speedBonus = max(0, Int((allowedSeconds - responseTime) * 10))

            let total = Int(Double(basePoints + speedBonus) * multiplierValue())

            score += total
            lastPointsGained = total

            feedback = .correct

            // Multiplayer: skor güncellemesini yayınla
            multiplayer?.reportScore(score)

            generateProblem()

        } else {

            SoundEngine.shared.play("wrong")
            FeedbackEngine.shared.error()

            feedback = .wrong
            captureContinueSnapshot(now: Date())
            isGameOver = true

            multiplayer?.reportScore(score)
        }
    }

    /// Rewarded reklamdan sonra aynı soru/süre/puan ile devam.
    func continueAfterReward() {
        guard canContinueWithAd else { return }
        guard !isMultiplayer else { return }

        // ✅ restore score + combo BEFORE resuming
        score = continueSnapshotScore
        comboCount = continueSnapshotComboCount
        comboLabel = continueSnapshotComboLabel
        lastPointsGained = continueSnapshotLastPoints

        isGameOver = false
        feedback = nil

        if let p = continueSnapshotProblem {
            problem = p
        }

        allowedSeconds = max(0.5, continueSnapshotAllowed)
        // ✅ Give a small grace time after rewarded revive so it doesn't instantly game over again.
        let minReviveRemaining = min(allowedSeconds, 5.0)
        let remaining = max(minReviveRemaining, min(continueSnapshotRemaining, allowedSeconds))

        // remaining’i koruyacak şekilde start time’ı geri sar
        questionStartTime = Date().addingTimeInterval(-(allowedSeconds - remaining))

        // bir kere devam hakkı
        canContinueWithAd = false
        continueSnapshotProblem = nil

        // snapshot reset
        continueSnapshotRemaining = 0
        continueSnapshotAllowed = 0
        continueSnapshotScore = 0
        continueSnapshotComboCount = 0
        continueSnapshotComboLabel = "x1"
        continueSnapshotLastPoints = 0
    }

    // MARK: - Internals

    private func resetRun() {
        score = 0
        comboCount = 0
        comboLabel = "x1"
        isGameOver = false
        feedback = nil
        lastPointsGained = 0

        // continue state reset
        canContinueWithAd = false
        continueSnapshotProblem = nil
        continueSnapshotRemaining = 0
        continueSnapshotAllowed = 0
        continueSnapshotScore = 0
        continueSnapshotComboCount = 0
        continueSnapshotComboLabel = "x1"
        continueSnapshotLastPoints = 0

        opponentScore = 0
        isRushMode = false
        isBossQuestion = false
    }

    private func generateProblem() {
        guard !isGameOver else { return }

        isBossQuestion = comboCount > 0 && comboCount % 7 == 0
        isRushMode = comboCount > 0 && comboCount % 4 == 0

        if isBossQuestion {
            SoundEngine.shared.play("boss")
            FeedbackEngine.shared.boss()
        }

        if isBossQuestion {
            allowedSeconds = 3
        } else if isRushMode {
            allowedSeconds = 4
        } else {
            allowedSeconds = 5
        }

        questionStartTime = Date()
        feedback = nil

        if isMultiplayer, var r = rng {
            // Swift value-type RNG: state'i geri yaz
            var rr = r
            problem = MathProblem.generate(isBoss: isBossQuestion, rng: &rr)
            rng = rr
        } else {
            problem = MathProblem.generate(isBoss: isBossQuestion)
        }
    }

    // MARK: Multiplier

    private func updateMultiplier() {
        switch comboCount {
        case 0...2:
            comboLabel = "x1"
        case 3...5:
            comboLabel = "x1.5"
        case 6...9:
            comboLabel = "x2"
        default:
            comboLabel = "x3"
        }
    }

    private func multiplierValue() -> Double {
        switch comboLabel {
        case "x1.5": return 1.5
        case "x2": return 2
        case "x3": return 3
        default: return 1
        }
    }

    // MARK: Points

    private func calculateBasePoints(problem: MathProblem) -> Int {
        if isBossQuestion { return 120 }
        if isRushMode { return 80 }

        if problem.question.contains("×") || problem.question.contains("÷") {
            return 60
        }
        return 40
    }

    // MARK: Timer Helpers

    func remainingSeconds(now: Date) -> Double {
        max(0, allowedSeconds - now.timeIntervalSince(questionStartTime))
    }

    func timeProgress(now: Date) -> CGFloat {
        CGFloat(remainingSeconds(now: now) / allowedSeconds)
    }
}

// MARK: Feedback Enum
enum FeedbackType {
    case correct
    case wrong
}
