//
//  SoundEngine.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import AVFoundation

final class SoundEngine {

    static let shared = SoundEngine()

    private var players: [String: AVAudioPlayer] = [:]

    private init() {}

    func play(_ name: String, ext: String = "mp3") {

        if let player = players[name] {
            player.currentTime = 0
            player.play()
            return
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Sound not found:", name)
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[name] = player
            player.play()
        } catch {
            print("Audio error:", error)
        }
    }
}
