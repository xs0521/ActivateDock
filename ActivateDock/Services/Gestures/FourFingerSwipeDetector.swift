//
//  FourFingerSwipeDetector.swift
//  ActivateDock
//

import Foundation
import OpenMultitouchSupport

struct FourFingerSwipeDetector {
    private struct Point {
        let x: Float
        let y: Float
    }

    private var startPoint: Point?
    private var startTime: TimeInterval = 0
    private var lastTriggerTime: TimeInterval = 0

    private let requiredTouches = 4
    private let maxGestureDuration: TimeInterval = 0.85
    private let cooldown: TimeInterval = 0.9
    private let minVerticalTravel: Float = 0.16
    private let maxHorizontalDrift: Float = 0.14

    mutating func consume(_ touches: [OMSTouchData]) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let active = touches.filter(Self.isActive)
        guard active.count == requiredTouches else {
            reset()
            return false
        }

        let center = Self.centroid(of: active)
        guard let start = startPoint else {
            begin(at: center, time: now)
            return false
        }

        if now - startTime > maxGestureDuration {
            begin(at: center, time: now)
            return false
        }

        let deltaX = center.x - start.x
        let deltaY = center.y - start.y
        guard abs(deltaX) <= maxHorizontalDrift else {
            reset()
            return false
        }

        guard deltaY <= -minVerticalTravel else { return false }
        guard now - lastTriggerTime >= cooldown else {
            reset()
            return false
        }

        lastTriggerTime = now
        reset()
        return true
    }

    mutating func reset() {
        startPoint = nil
        startTime = 0
    }

    private mutating func begin(at point: Point, time: TimeInterval) {
        startPoint = point
        startTime = time
    }

    private static func isActive(_ touch: OMSTouchData) -> Bool {
        switch touch.state {
        case .starting, .making, .touching:
            return true
        case .notTouching, .hovering, .breaking, .lingering, .leaving:
            return false
        }
    }

    private static func centroid(of touches: [OMSTouchData]) -> Point {
        let total = touches.reduce(Point(x: 0, y: 0)) { partial, touch in
            Point(
                x: partial.x + touch.position.x,
                y: partial.y + touch.position.y
            )
        }
        let count = Float(touches.count)
        return Point(x: total.x / count, y: total.y / count)
    }
}
