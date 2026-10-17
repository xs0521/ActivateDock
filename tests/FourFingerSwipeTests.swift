import Foundation

@main
struct FourFingerSwipeTests {
    static func frame(_ y: Float, x: Float = 0.5, count: Int = 4, state: Int32 = 4) -> [ADTouch] {
        (0..<count).map { _ in
            let touch = ADTouch()
            touch.x = x
            touch.y = y
            touch.state = state
            return touch
        }
    }

    static func main() {
        var detector = FourFingerSwipeDetector()
        assert(!detector.consume(frame(0.8), now: 10))
        assert(detector.consume(frame(0.65), now: 10.2))
        assert(!detector.consume(frame(0.8), now: 10.3))
        assert(!detector.consume(frame(0.65), now: 10.4), "cooldown")
        assert(!detector.consume(frame(0.8, count: 2), now: 11))
        assert(!detector.consume(frame(0.6, count: 2), now: 11.2), "two fingers")
        assert(!detector.consume(frame(0.6), now: 12))
        assert(!detector.consume(frame(0.8), now: 12.2), "upward swipe")
        detector.reset()
        assert(!detector.consume(frame(0.8), now: 13))
        assert(!detector.consume(frame(0.6, x: 0.9), now: 13.2), "horizontal drift")
        assert(!detector.consume(frame(0.8), now: 14))
        assert(!detector.consume(frame(0.6), now: 15.3), "expired gesture")
        detector.reset()
        assert(!detector.consume(frame(0.8, state: 2), now: 16))
        assert(!detector.consume(frame(0.6, state: 2), now: 16.2), "hovering")

        // Interleaved empty and moving frames from another device cannot affect
        // a swipe on the external trackpad.
        var devices: [UInt: FourFingerSwipeDetector] = [:]
        assert(!devices[2, default: .init()].consume(frame(0.8), now: 20))
        assert(!devices[1, default: .init()].consume([], now: 20.1))
        assert(devices[2, default: .init()].consume(frame(0.6), now: 20.2))
        assert(!devices[1, default: .init()].consume(frame(0.8), now: 20.3))
        assert(devices[1, default: .init()].consume(frame(0.6), now: 20.5))
        devices.removeAll()
        assert(!devices[2, default: .init()].consume(frame(0.5), now: 21), "reconnect clears state")
        print("PASS: swipe direction, finger count, cooldown, timeout, hover and independent devices")
    }
}
