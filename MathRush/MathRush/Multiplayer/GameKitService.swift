//
//  GameKitService.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import Foundation
import GameKit
import UIKit

protocol GameKitServiceDelegate: AnyObject {
    func serviceDidBecomeReady()
    func serviceDidReceive(_ message: NetworkMessage)
    func serviceDidFail(_ error: Error)
}

final class GameKitService: NSObject {

    weak var delegate: GameKitServiceDelegate?

    private(set) var currentMatch: GKMatch?

    func authenticateIfNeeded() {
        GKLocalPlayer.local.authenticateHandler = { vc, error in
            if let error {
                self.delegate?.serviceDidFail(error)
                return
            }
            if let vc {
                Self.topViewController()?.present(vc, animated: true)
            }
        }
    }

    func startMatchmakingTwoPlayers() {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2

        guard let mmvc = GKMatchmakerViewController(matchRequest: request) else { return }
        mmvc.matchmakerDelegate = self
        Self.topViewController()?.present(mmvc, animated: true)
    }

    func send(_ message: NetworkMessage, mode: GKMatch.SendDataMode = .reliable) {
        guard let match = currentMatch else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try match.sendData(toAllPlayers: data, with: mode)
        } catch {
            delegate?.serviceDidFail(error)
        }
    }

    // MARK: - UI Helper

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let root = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        return topMost(from: root)
    }

    private static func topMost(from vc: UIViewController?) -> UIViewController? {
        if let nav = vc as? UINavigationController { return topMost(from: nav.visibleViewController) }
        if let tab = vc as? UITabBarController { return topMost(from: tab.selectedViewController) }
        if let presented = vc?.presentedViewController { return topMost(from: presented) }
        return vc
    }
}

extension GameKitService: GKMatchmakerViewControllerDelegate {

    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        delegate?.serviceDidFail(error)
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)

        currentMatch = match
        match.delegate = self

        if match.expectedPlayerCount == 0 {
            delegate?.serviceDidBecomeReady()
        }
    }
}

extension GameKitService: GKMatchDelegate {

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        if state == .connected, match.expectedPlayerCount == 0 {
            delegate?.serviceDidBecomeReady()
        }
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        do {
            let msg = try JSONDecoder().decode(NetworkMessage.self, from: data)
            delegate?.serviceDidReceive(msg)
        } catch {
            delegate?.serviceDidFail(error)
        }
    }
}
