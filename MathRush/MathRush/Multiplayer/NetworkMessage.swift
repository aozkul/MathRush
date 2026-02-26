//
//  NetworkMessage.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import Foundation

enum NetworkMessage: Codable {
    case start(StartPayload)
    case score(ScorePayload)
}

struct StartPayload: Codable {
    let seed: Int
    let startAtEpoch: TimeInterval
    let durationSeconds: Int
}

struct ScorePayload: Codable {
    let score: Int
}
