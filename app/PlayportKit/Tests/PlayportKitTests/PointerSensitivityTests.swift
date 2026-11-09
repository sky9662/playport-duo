// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest
@testable import PlayportKit

final class PointerSensitivityTests: XCTestCase {
    func testInGameStepsReach250PercentAndClampOrWrapAtEnds() {
        XCTAssertEqual(PointerSensitivity.step(2, by: 1), 2.5)
        XCTAssertEqual(PointerSensitivity.step(3, by: -1), 2.5)
        XCTAssertEqual(PointerSensitivity.step(4, by: 1), 4)
        XCTAssertEqual(PointerSensitivity.step(4, by: 1, wrapping: true), 0.1)
        XCTAssertEqual(PointerSensitivity.step(0.1, by: -1), 0.1)
        let rows = QuickMenuControlsRow.shown(controller: false, state: ControlsState.resolve(game: nil, defaults: ControlsDefaults(), controllerConnected: false))
        XCTAssertTrue(rows.contains(.trackpadSensitivity))
        XCTAssertTrue(rows.contains(.mouseSensitivity))
    }
    func testOldRecordsInheritAndNewFieldsRoundTrip() throws {
        var game = try JSONDecoder().decode(GameControls.self, from: Data("{}".utf8))
        XCTAssertTrue(game.isEmpty)
        let defaults = ControlsDefaults()
        XCTAssertEqual(game.trackpadSensitivity(over: defaults), 1)
        XCTAssertEqual(game.mouseSensitivity(over: defaults), 1)
        game.trackpadSensitivity = 0.25
        game.mouseSensitivity = 3
        XCTAssertFalse(game.isEmpty)
        let decoded = try JSONDecoder().decode(GameControls.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(decoded.trackpadSensitivity(over: defaults), 0.25)
        XCTAssertEqual(decoded.mouseSensitivity(over: defaults), 3)
        game.trackpadSensitivity = nil
        XCTAssertEqual(game.trackpadSensitivity(over: defaults), 1)
        XCTAssertEqual(game.mouseSensitivity(over: defaults), 3)
    }

    func testInvalidValuesInheritAndGlobalPersistence() {
        let defaults = UserDefaults(suiteName: "PointerSensitivityTests")!
        defer { defaults.removePersistentDomain(forName: "PointerSensitivityTests") }
        defaults.set("0.25", forKey: PointerSensitivity.trackpadKey)
        defaults.set(2.0, forKey: PointerSensitivity.mouseKey)
        let global = ControlsDefaults(defaults)
        XCTAssertEqual(global.trackpadSensitivity, 0.25)
        XCTAssertEqual(global.mouseSensitivity, 2)
        var game = GameControls()
        for value in [Double.nan, .infinity, -1, 0, 5] {
            game.trackpadSensitivity = value
            game.mouseSensitivity = value
            XCTAssertEqual(game.trackpadSensitivity(over: global), 0.25)
            XCTAssertEqual(game.mouseSensitivity(over: global), 2)
        }
    }
}
