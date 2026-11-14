// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest
@testable import PlayportKit

final class PointerAccelerationSettingsTests: XCTestCase {
    func testOldRecordsDefaultOnAndExplicitOffSurvivesRoundTripAndNormalization() throws {
        var game = try JSONDecoder().decode(GameControls.self, from: Data("{}".utf8))
        XCTAssertTrue(game.isEmpty)
        XCTAssertTrue(game.pointerAcceleration(over: ControlsDefaults()))
        game.pointerAcceleration = false
        XCTAssertFalse(game.isEmpty)
        var records = GameControlsRecords()
        records.set("test-game", game)
        let decoded = try XCTUnwrap(GameControlsRecords(json: records.json())?["test-game"])
        XCTAssertEqual(decoded.pointerAcceleration, false)
        XCTAssertFalse(decoded.pointerAcceleration(over: ControlsDefaults()))
        game.pointerAcceleration = nil
        XCTAssertTrue(game.isEmpty)
    }

    func testGlobalOffIsInheritedAndGameCanOverrideWithoutChangingSensitivity() throws {
        let defaults = UserDefaults(suiteName: "PointerAccelerationSettingsTests")!
        defer { defaults.removePersistentDomain(forName: "PointerAccelerationSettingsTests") }
        defaults.set(false, forKey: PointerSensitivity.accelerationKey)
        defaults.set(2.5, forKey: PointerSensitivity.trackpadKey)
        let global = ControlsDefaults(defaults)
        XCTAssertFalse(global.pointerAcceleration)
        var game = GameControls()
        XCTAssertFalse(game.pointerAcceleration(over: global))
        game.pointerAcceleration = true
        XCTAssertTrue(game.pointerAcceleration(over: global))
        XCTAssertEqual(game.trackpadSensitivity(over: global), 2.5)
        let rows = QuickMenuControlsRow.shown(controller: false,
            state: ControlsState.resolve(game: nil, defaults: global, controllerConnected: false))
        XCTAssertTrue(rows.contains(.pointerAcceleration))
    }
}
