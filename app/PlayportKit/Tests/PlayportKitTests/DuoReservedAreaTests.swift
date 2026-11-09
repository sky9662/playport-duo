// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import HostIOKit
@testable import PlayportKit
final class DuoReservedAreaTests: XCTestCase {
    func testCameraAndAsymmetricInsets() {
        let initial = ControlInsets(top: 10, left: 20, bottom: 30, right: 40)
        let top = initial.avoiding([TouchRect(x: 400, y: 0, width: 50, height: 50)], width: 900, height: 600)
        XCTAssertEqual(top, ControlInsets(top: 50, left: 20, bottom: 30, right: 40))
        let left = initial.avoiding([TouchRect(x: 0, y: 200, width: 60, height: 30)], width: 900, height: 600)
        XCTAssertEqual(left, ControlInsets(top: 10, left: 60, bottom: 30, right: 40))
    }
    func testFullHeightOcclusionLeavesUsableControlArea() {
        let safe = ControlInsets().avoiding([TouchRect(x: 400, y: 0, width: 20, height: 600)], width: 900, height: 600)
        let area = safe.area(width: 900, height: 600)
        XCTAssertEqual(area.x, 420)
        XCTAssertEqual(area.width, 480)
        XCTAssertEqual(area.height, 600)
    }
    func testOutsideOrAlreadyExcludedRegionsDoNotMoveControls() {
        let initial = ControlInsets(top: 50, left: 20, bottom: 30, right: 40)
        XCTAssertEqual(initial.avoiding([TouchRect(x: 400, y: 0, width: 50, height: 40),
                                         TouchRect(x: 1000, y: 0, width: 20, height: 20)], width: 900, height: 600), initial)
    }
}
