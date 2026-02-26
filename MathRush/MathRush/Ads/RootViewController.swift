//
//  RootViewController.swift
//  MathRush
//
//  Created by Ali Ozkul on 25.02.26.
//

import UIKit

enum RootViewController {

    /// App içindeki en üstte görünen UIViewController'ı döndürür.
    /// Rewarded / Interstitial reklamları SwiftUI'den göstermek için kullanılır.
    static var topMost: UIViewController? {
        // aktif window scene bul
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        // en öndeki (foregroundActive) scene'i tercih et
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first

        // key window bul
        let keyWindow = activeScene?.windows.first(where: { $0.isKeyWindow }) ?? activeScene?.windows.first

        guard let root = keyWindow?.rootViewController else { return nil }
        return topMost(from: root)
    }

    private static func topMost(from vc: UIViewController) -> UIViewController {
        // presented (modal) varsa ona git
        if let presented = vc.presentedViewController {
            return topMost(from: presented)
        }

        // UINavigationController stack
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }

        // UITabBarController seçili tab
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }

        return vc
    }
}
