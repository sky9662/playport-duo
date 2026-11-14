// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import PlayportKit

final class DeviceUIProfileTests: XCTestCase {
    func testOnlyExactDuoHardwareEnablesItsPresentation() {
        XCTAssertEqual(DeviceUIProfile(machineIdentifier: "iPhone19,4"), .duo)
        for identifier in ["iPhone18,1", "iPhone19,1", "iPhone19,2", "iPhone19,3", "iPhone19,40", "iPad16,3", "iPad17,1", "arm64", "x86_64", "", "iPhone Duo", "iPhone20,4"] {
            XCTAssertEqual(DeviceUIProfile(machineIdentifier: identifier), .standard, identifier)
        }
    }

    func testOtherDevicesKeepFourColumnsAtEveryWindowWidthAndNeverUseInnerControls() {
        for identifier in ["iPhone18,1", "iPhone19,2", "iPad16,3", "iPad17,1", "unknown"] {
            let profile = DeviceUIProfile(machineIdentifier: identifier)
            for width in [320.0, 414, 660, 760, 824, 1024, 1366, 2000] {
                XCTAssertEqual(profile.libraryColumns(width: width), 4, identifier)
            }
            XCTAssertFalse(profile.expandedControls(isRegular: true), identifier)
            XCTAssertFalse(profile.expandedControls(isRegular: false), identifier)
        }
    }

    func testDuoKeepsResponsiveGridAndSeparateFoldedAndExpandedControls() {
        let profile = DeviceUIProfile(machineIdentifier: "iPhone19,4")
        XCTAssertFalse(profile.expandedControls(isRegular: false))
        XCTAssertTrue(profile.expandedControls(isRegular: true))
        XCTAssertEqual(profile.libraryColumns(width: 320), 2)
        XCTAssertEqual(profile.libraryColumns(width: 800), 5)
        XCTAssertEqual(profile.libraryColumns(width: 1366), 6)
    }
}
