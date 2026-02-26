//
//  SeededRandomGenerator.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import Foundation

struct SeededRandomGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
