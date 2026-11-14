// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import HostIOKit

final class TouchAccelerationTests: XCTestCase {
    func testCurveIsContinuousMonotonicBoundedAndIgnoresDirection() {
        var previous = 0.5
        for speed in stride(from: 0.0, through: 1000, by: 1) {
            let gain = TouchAcceleration.gain(dx: speed / 100, dy: 0, elapsed: 0.01)
            XCTAssertGreaterThanOrEqual(gain, previous)
            XCTAssertLessThanOrEqual(gain, 1.5)
            XCTAssertEqual(gain, TouchAcceleration.gain(dx: 0, dy: -speed / 100, elapsed: 0.01), accuracy: 1e-12)
            previous = gain
        }
        XCTAssertEqual(TouchAcceleration.gain(dx: 0.6, dy: 0, elapsed: 0.01), 0.5)
        XCTAssertEqual(TouchAcceleration.gain(dx: 6, dy: 0, elapsed: 0.01), 1.5)
    }

    func testSameVelocityHasSameGainAt60And120HzAndInvalidTimesStayLinear() {
        XCTAssertEqual(TouchAcceleration.gain(dx: 240.0 / 60, dy: 0, elapsed: 1.0 / 60),
                       TouchAcceleration.gain(dx: 240.0 / 120, dy: 0, elapsed: 1.0 / 120), accuracy: 1e-12)
        for elapsed in [0.0, -1, .nan, .infinity] {
            XCTAssertEqual(TouchAcceleration.gain(dx: 1, dy: 0, elapsed: elapsed), 1)
        }
    }

    private func controls(pointer: Bool, accelerated: Bool) -> TouchControls {
        let frame = TouchRect(x: 0, y: 0, width: 800, height: 400)
        var controls = TouchControls(targets: [TouchTarget(id: "surface", kind: pointer ? .pointer(view: frame) : .look, frame: frame)])
        controls.trackpad = true
        controls.trackpadScale = 4
        controls.lookScale = 4
        controls.pointerAcceleration = accelerated
        return controls
    }

    func testTrackpadAndLookApplyImmediatelyAndOffPreservesLinearDeltas() {
        for pointer in [false, true] {
            for accelerated in [false, true] {
                var t = controls(pointer: pointer, accelerated: accelerated)
                XCTAssertTrue(t.began(1, at: TouchPoint(x: 100, y: 100), time: 0))
                t.moved(1, at: TouchPoint(x: 102, y: 100), time: 0.1)
                XCTAssertEqual(t.takeOutput().events, [.move(dx: accelerated ? 4 : 8, dy: 0)])
                t.moved(1, at: TouchPoint(x: 112, y: 100), time: 0.11)
                XCTAssertEqual(t.takeOutput().events, [.move(dx: accelerated ? 60 : 40, dy: 0)])
                t.ended(1, time: 0.5)
                _ = t.takeOutput()
                XCTAssertTrue(t.began(2, at: TouchPoint(x: 100, y: 100), time: 1))
                t.moved(2, at: TouchPoint(x: 102, y: 100), time: 1.1)
                XCTAssertEqual(t.takeOutput().events, [.move(dx: accelerated ? 4 : 8, dy: 0)])
            }
        }
    }

    func testSlowSubcountMovementIsCarriedAndTapStillClicks() {
        var t = controls(pointer: true, accelerated: true)
        t.trackpadScale = 5
        XCTAssertTrue(t.began(1, at: TouchPoint(x: 100, y: 100), time: 0))
        for i in 1...4 {
            t.moved(1, at: TouchPoint(x: 100 + Double(i) * 0.1, y: 100), time: Double(i) * 0.01)
        }
        // Binary rounding can leave the exact 1-count boundary just below 1.
        t.moved(1, at: TouchPoint(x: 100.41, y: 100), time: 0.05)
        XCTAssertEqual(t.takeOutput().events, [.move(dx: 1, dy: 0)])
        t.ended(1, time: 0.1)
        XCTAssertEqual(t.takeOutput().events, [.click(.left)])
    }

    func testAccelerationDoesNotChangeAbsolutePointingOrScrolling() {
        for scroll in [false, true] {
            func events(_ accelerated: Bool) -> [TouchPointerEvent] {
                var t = controls(pointer: true, accelerated: accelerated)
                t.trackpad = scroll
                if scroll {
                    t.setTargets(t.targets + [TouchTarget(id: "scroll", kind: .tool(.scroll),
                        frame: TouchRect(x: 700, y: 0, width: 100, height: 100))])
                    _ = t.began(99, at: TouchPoint(x: 710, y: 10), time: 0)
                    t.ended(99, time: 0)
                }
                _ = t.began(1, at: TouchPoint(x: 100, y: 100), time: 0)
                t.moved(1, at: TouchPoint(x: 200, y: 140), time: 0.01)
                return t.takeOutput().events
            }
            XCTAssertEqual(events(true), events(false))
        }
    }
}
