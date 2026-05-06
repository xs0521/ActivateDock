//
//  AccentPalette.swift
//  ActivateDock
//

import Cocoa

enum AccentPalette {
    static let candidates: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemMint, .systemTeal, .systemCyan, .systemBlue,
        .systemIndigo, .systemPurple, .systemPink, .systemBrown
    ]

    static func nextColor(excluding used: Set<NSColor>) -> NSColor {
        let available = candidates.filter { !used.contains($0) }
        if let pick = available.randomElement() { return pick }
        return randomHSB()
    }

    static func uniqueColors(count: Int) -> [NSColor] {
        var pool = candidates.shuffled()
        var result: [NSColor] = []
        for _ in 0..<count {
            if let next = pool.popLast() {
                result.append(next)
            } else {
                result.append(randomHSB())
            }
        }
        return result
    }

    private static func randomHSB() -> NSColor {
        NSColor(
            hue: .random(in: 0...1),
            saturation: .random(in: 0.55...0.85),
            brightness: .random(in: 0.75...0.95),
            alpha: 1
        )
    }
}
