//
//  AdManager.swift
//  MathRush
//
//  Created by Ali Ozkul on 25.02.26.
//

import GoogleMobileAds
import Combine

final class AdManager: NSObject, ObservableObject {

    static let shared = AdManager()

    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?

    @Published var gamesPlayed = 0

    // Interstitial gating
    private var interstitialCompletion: (() -> Void)?

    // MARK: LOAD REWARDED
    func loadRewarded() {
        RewardedAd.load(
            with: "ca-app-pub-2644845915949868/2060167339",
            request: Request()
        ) { ad, error in
            if let error = error {
                print("Rewarded load error:", error)
                self.rewardedAd = nil
                return
            }
            self.rewardedAd = ad
        }
    }

    // MARK: SHOW REWARDED
    func showRewarded(from vc: UIViewController,
                      reward: @escaping () -> Void) {

        guard let ad = rewardedAd else { return }

        ad.present(from: vc) {
            reward()
        }

        loadRewarded()
    }

    // MARK: INTERSTITIAL
    func loadInterstitial() {
        InterstitialAd.load(
            with: "ca-app-pub-2644845915949868/9652075682",
            request: Request()
        ) { ad, error in
            if let error = error {
                print("Interstitial load error:", error)
                self.interstitialAd = nil
                return
            }
            self.interstitialAd = ad
        }
    }

    func showInterstitial(from vc: UIViewController) {
        // Show an interstitial only every 3 finished single-player games.
        guard gamesPlayed >= 3 else { return }

        if let ad = interstitialAd {
            ad.present(from: vc)
            gamesPlayed = 0
            loadInterstitial()
        } else {
            // If not ready, just start loading and try next time.
            loadInterstitial()
        }
    }

    /// Call this when a **single-player game ends** and the user is about to start a new run.
    /// - Shows an interstitial every 3 finished games.
    /// - Calls `completion` after the ad is dismissed (or immediately if no ad is shown).
    func noteSinglePlayerGameFinishedAndMaybeShowInterstitial(from vc: UIViewController,
                                                             completion: @escaping () -> Void) {
        gamesPlayed += 1

        // Not yet time for an interstitial → continue immediately.
        guard gamesPlayed >= 3 else {
            completion()
            return
        }

        // If the interstitial isn't ready, don't block the flow.
        guard let ad = interstitialAd else {
            loadInterstitial()
            completion()
            return
        }

        // Present and resume after dismissal.
        interstitialCompletion = completion
        ad.fullScreenContentDelegate = self
        ad.present(from: vc)

        gamesPlayed = 0
    }

    /// Backward compatible call site.
    func noteSinglePlayerGameFinishedAndMaybeShowInterstitial(from vc: UIViewController) {
        noteSinglePlayerGameFinishedAndMaybeShowInterstitial(from: vc, completion: {})
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let cb = interstitialCompletion
        interstitialCompletion = nil
        loadInterstitial()
        cb?()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial present error:", error)
        let cb = interstitialCompletion
        interstitialCompletion = nil
        loadInterstitial()
        cb?()
    }
}
