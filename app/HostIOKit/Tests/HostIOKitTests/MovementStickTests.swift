// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import HostIOKit

final class MovementStickTests: XCTestCase {
    let zone = TouchRect(x: 0, y: 200, width: 400, height: 300)
    let wasd: [InputAction] = [.key(0x57, []), .key(0x53, []), .key(0x41, []), .key(0x44, [])]

    func testVisualSizeDoesNotChangeAnalogMovementOrKeyThresholds() {
        for size in [24.0, 104, 208, 400] {
            for kind in [TouchTarget.Kind.stick(.leftStick, zone: zone), .keyStick(wasd, zone: zone)] {
                let target = TouchTarget(id: "move", kind: kind, frame: TouchRect(x: 20, y: 220, width: size, height: size))
                var state = TouchControls(targets: [target])
                XCTAssertTrue(state.began(1, at: TouchPoint(x: 350, y: 450), time: 0))
                XCTAssertEqual(state.output, TouchOutput())
                state.moved(1, at: TouchPoint(x: 350, y: 425), time: 0.01)
                if case .keyStick = kind { XCTAssertTrue(state.output.keys.isEmpty) }
                else { XCTAssertEqual(state.output.pad.ly, 25.0 / 52, accuracy: 0.0001) }
                state.moved(1, at: TouchPoint(x: 350, y: 424), time: 0.02)
                if case .keyStick = kind {
                    XCTAssertEqual(state.output.keys, [.key(0x57, [])])
                    state.moved(1, at: TouchPoint(x: 350, y: 429), time: 0.03)
                    XCTAssertEqual(state.output.keys, [.key(0x57, [])])
                    state.moved(1, at: TouchPoint(x: 350, y: 430), time: 0.04)
                    XCTAssertTrue(state.output.keys.isEmpty)
                } else { XCTAssertEqual(state.output.pad.ly, 0.5, accuracy: 0.0001) }
                state.ended(1, time: 0.05)
                XCTAssertEqual(state.output, TouchOutput())
            }
        }
    }

    func testBroadZoneCapturesOutsideGlyphAndKeepsFingerUntilLift() {
        let stick = TouchTarget(id: "move", kind: .keyStick(wasd, zone: zone), frame: TouchRect(x: 30, y: 320, width: 24, height: 24))
        let look = TouchTarget(id: "look", kind: .look, frame: TouchRect(x: 0, y: 0, width: 800, height: 600))
        let button = TouchTarget(id: "jump", kind: .button(.key(0x20, []), .hold), frame: TouchRect(x: 300, y: 300, width: 50, height: 50))
        var state = TouchControls(targets: [look, stick, button])
        XCTAssertEqual(state.target(at: TouchPoint(x: 320, y: 320)), 2)
        XCTAssertEqual(state.target(at: TouchPoint(x: 500, y: 450)), 0)
        XCTAssertTrue(state.began(1, at: TouchPoint(x: 350, y: 450), time: 0))
        state.moved(1, at: TouchPoint(x: 500, y: 450), time: 0.05)
        let output = state.takeOutput()
        XCTAssertEqual(output.keys, [.key(0x44, [])])
        XCTAssertTrue(output.events.isEmpty, "a captured stick never becomes mouse look")
        state.cancelled(1, time: 0.06)
        XCTAssertEqual(state.output, TouchOutput())
        XCTAssertTrue(state.began(2, at: TouchPoint(x: 250, y: 350), time: 0.1))
        XCTAssertEqual(state.output, TouchOutput(), "the new landing is neutral")
        state.releaseAll()
        XCTAssertEqual(state.output, TouchOutput())
    }
}
