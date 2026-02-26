//
//  MainMenuView.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import SwiftUI

struct MainMenuView: View {

    @StateObject private var multiplayer = MultiplayerCoordinator()
    @StateObject private var singlePlayerVM = GameViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {

                // ✅ LOGO
                Image("app_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240)
                    .padding(.top, 24)

                Text("Fast. Fun. Math.")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 8)

                NavigationLink {
                    GameView(vm: singlePlayerVM)
                } label: {
                    Text("Single Player")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.12))
                        .cornerRadius(18)
                        .foregroundColor(.white)
                }

                NavigationLink {
                    MultiplayerLobbyView(multiplayer: multiplayer)
                } label: {
                    Text("Multiplayer")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.12))
                        .cornerRadius(18)
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [.black, .purple.opacity(0.9), .blue.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
}
