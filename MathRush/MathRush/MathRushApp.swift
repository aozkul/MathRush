//
//  MathRushApp.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import SwiftUI
import GoogleMobileAds

@main
struct MathRushApp: App {
    init() {
        MobileAds.shared.start(completionHandler: nil)
        AdManager.shared.loadRewarded()
        AdManager.shared.loadInterstitial()
    }

    var body: some Scene {
        WindowGroup { MainMenuView() }
    }
}
