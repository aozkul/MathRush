//
//  MultiplayerCoordinator.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import Foundation
import Combine
import GameKit

@MainActor
final class MultiplayerCoordinator: ObservableObject {

    @Published var statusText: String = "Not connected"
    @Published var shouldNavigateToGame: Bool = false

    private let service = GameKitService()
    private weak var boundViewModel: GameViewModel?

    private var didStartGame = false
    private var startPayload: StartPayload?

    init() {
        service.delegate = self
    }

    func authenticateIfNeeded() {
        service.authenticateIfNeeded()
    }

    func startMatchmaking() {
        didStartGame = false
        startPayload = nil
        statusText = "Finding match..."
        service.startMatchmakingTwoPlayers()
    }

    func bindToGameViewModel(_ vm: GameViewModel) {
        boundViewModel = vm

        // Start mesajı daha önce geldiyse (race condition), VM bağlanınca başlat
        if let payload = startPayload, !didStartGame {
            didStartGame = true
            vm.startMultiplayer(
                coordinator: self,
                seed: payload.seed,
                startAtEpoch: payload.startAtEpoch,
                durationSeconds: payload.durationSeconds
            )
        }
    }

    func reportScore(_ score: Int) {
        service.send(.score(ScorePayload(score: score)), mode: .unreliable)
    }

    private func isLocalHost(match: GKMatch) -> Bool {
        // deterministic host: en küçük gamePlayerID host
        let local = GKLocalPlayer.local.gamePlayerID
        let remoteIDs = match.players.map { $0.gamePlayerID }
        let all = ([local] + remoteIDs).sorted()
        return all.first == local
    }
}

extension MultiplayerCoordinator: GameKitServiceDelegate {

    func serviceDidBecomeReady() {
        statusText = "Match found ✅ Preparing..."
        shouldNavigateToGame = true

        guard let match = service.currentMatch else {
            // Çok nadir edge-case; gene de host olup başlat
            let payload = StartPayload(
                seed: Int.random(in: 0...999_999),
                startAtEpoch: Date().addingTimeInterval(3).timeIntervalSince1970,
                durationSeconds: 60
            )
            startPayload = payload
            service.send(.start(payload))
            return
        }

        // Host sadece 1 kişi olsun; iki taraf aynı anda start yollamasın
        if isLocalHost(match: match) {
            let payload = StartPayload(
                seed: Int.random(in: 0...999_999),
                startAtEpoch: Date().addingTimeInterval(3).timeIntervalSince1970,
                durationSeconds: 60
            )
            startPayload = payload
            service.send(.start(payload))
        } else {
            statusText = "Connected ✅ Waiting host..."
        }
    }

    func serviceDidReceive(_ message: NetworkMessage) {
        switch message {
        case .start(let payload):
            statusText = "Starting..."
            startPayload = payload

            if let vm = boundViewModel, !didStartGame {
                didStartGame = true
                vm.startMultiplayer(
                    coordinator: self,
                    seed: payload.seed,
                    startAtEpoch: payload.startAtEpoch,
                    durationSeconds: payload.durationSeconds
                )
            }

        case .score(let payload):
            boundViewModel?.applyOpponentScore(payload.score)
        }
    }

    func serviceDidFail(_ error: Error) {
        statusText = "Error: \(error.localizedDescription)"
    }
}
