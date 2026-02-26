//
//  MultiplayerLobbyView.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import SwiftUI

struct MultiplayerLobbyView: View {

    @ObservedObject var multiplayer: MultiplayerCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Text("Multiplayer Lobby")
                .font(.title.bold())

            Text(multiplayer.statusText)
                .foregroundColor(.secondary)

            Button {
                multiplayer.startMatchmaking()
            } label: {
                Text("Find Match (2 Players)")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.cyan.opacity(0.2))
                    .cornerRadius(16)
            }

            Spacer()
        }
        .padding(20)
        .onAppear { multiplayer.authenticateIfNeeded() }
        .navigationDestination(isPresented: $multiplayer.shouldNavigateToGame) {
            GameHostView(multiplayer: multiplayer)
        }
    }
}
