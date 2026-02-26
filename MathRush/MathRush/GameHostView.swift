//
//  GameHostView.swift
//  MathRush
//
//  Created by Ali Ozkul on 26.02.26.
//

import SwiftUI

struct GameHostView: View {
    @StateObject private var vm = GameViewModel()

    let multiplayer: MultiplayerCoordinator?

    init(multiplayer: MultiplayerCoordinator? = nil) {
        self.multiplayer = multiplayer
    }

    var body: some View {
        GameView(vm: vm, multiplayer: multiplayer)
            .onAppear {
                // Single player ise oyunu sadece *ilk kez* başlat.
                // Rewarded reklam kapanınca view tekrar onAppear alabiliyor;
                // burada startSinglePlayer çağırmak skoru sıfırlar.
                if multiplayer == nil, vm.problem == nil {
                    vm.startSinglePlayer()
                }
            }
    }
}
