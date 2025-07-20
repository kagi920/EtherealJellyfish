//
//  AudioDataActor.swift
//  EtherealJellyfish
//
//  Created by kagi on 2025/07/20.
//

import Foundation

actor AudioDataActor {
    private var magnitudes: [Float] = []

    func updateMagnitudes(_ newMagnitudes: [Float]) {
        self.magnitudes = newMagnitudes
    }

    func getMagnitudes() -> [Float] {
        return magnitudes
    }
}
