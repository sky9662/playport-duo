// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import HostIOKit
@testable import PlayportKit

final class StickZoneEditorTests: XCTestCase {
    func testAreaSizeIndependentFromGlyphAndUndoAndSerialization() throws {
        var editor = LayoutEditor(preset: .keyboardMouse, width: 800, height: 600)
        let original = editor.layout
        let glyph = editor.frame(of: "move")
        editor.useLowerLeftStickZone("move")
        XCTAssertEqual(editor.zone(of: "move"), TouchRect(x: 0, y: 300, width: 400, height: 300))
        XCTAssertEqual(editor.frame(of: "move")?.width, glyph?.width)
        XCTAssertEqual(editor.frame(of: "move")?.x, 200 - (glyph?.width ?? 0) / 2)
        XCTAssertEqual(editor.frame(of: "move")?.y, 450 - (glyph?.height ?? 0) / 2)
        editor.resizeStickZone("move", horizontally: true, by: 2)
        editor.resizeStickZone("move", horizontally: false, by: 1)
        XCTAssertEqual(editor.zone(of: "move"), TouchRect(x: 0, y: 284, width: 432, height: 316))
        let centred = try XCTUnwrap(editor.frame(of: "move"))
        XCTAssertEqual(centred.x + centred.width / 2, 216)
        XCTAssertEqual(centred.y + centred.height / 2, 442)
        let zone = editor.zone(of: "move")
        editor.pinch("move", scale: 2)
        editor.endGesture()
        XCTAssertEqual(editor.zone(of: "move"), zone)
        XCTAssertNotEqual(editor.frame(of: "move"), glyph)
        XCTAssertEqual(try JSONDecoder().decode(ControlLayout.self, from: JSONEncoder().encode(editor.layout)), editor.layout)
        XCTAssertNil(editor.layout.problem)
        editor.undo(); editor.undo(); editor.undo(); editor.undo()
        XCTAssertEqual(editor.layout, original)
        editor.redo()
        XCTAssertEqual(editor.zone(of: "move")?.width, 400)
    }

    func testAreaClampsToSafeBoundsAndGroupScalingKeepsItsSize() throws {
        var editor = LayoutEditor(preset: .keyboardMouse, width: 800, height: 600, insets: ControlInsets(top: 10, left: 20, bottom: 30, right: 40))
        editor.useLowerLeftStickZone("move")
        editor.resizeStickZone("move", horizontally: true, by: 1000)
        editor.resizeStickZone("move", horizontally: false, by: 1000)
        XCTAssertEqual(editor.zone(of: "move"), TouchRect(x: 20, y: 10, width: 740, height: 560))
        editor.resizeStickZone("move", horizontally: true, by: -1000)
        editor.resizeStickZone("move", horizontally: false, by: -1000)
        XCTAssertEqual(editor.zone(of: "move")?.width, 24)
        XCTAssertEqual(editor.zone(of: "move")?.height, 24)
        editor.select("move"); editor.toggleSelection("jump")
        editor.pinch("move", scale: 1.2); editor.endGesture()
        XCTAssertEqual(editor.zone(of: "move")?.width, 24)
        XCTAssertEqual(editor.zone(of: "move")?.height, 24)
        XCTAssertNil(editor.layout.problem)
    }

    func testFixedStickCanAcquireAZoneWithoutChangingItsAppearance() throws {
        var editor = LayoutEditor(preset: .keyboardMouse, width: 800, height: 600)
        let id = try XCTUnwrap(editor.add(.keyStick))
        let glyph = try XCTUnwrap(editor.frame(of: id))
        XCTAssertNil(editor.zone(of: id))
        editor.resizeStickZone(id, horizontally: true, by: 1)
        XCTAssertEqual(editor.frame(of: id), glyph)
        XCTAssertEqual(editor.zone(of: id)?.width, glyph.width + 16)
        XCTAssertEqual(editor.zone(of: id)?.height, glyph.height)
        editor.undo()
        XCTAssertNil(editor.zone(of: id))
    }

    func testResizingAboutCentreExpandsBothSidesAndKeepsGlyphCentred() throws {
        var editor = LayoutEditor(preset: .keyboardMouse, width: 800, height: 600)
        let id = try XCTUnwrap(editor.add(.keyStick))
        editor.resizeStickZone(id, horizontally: true, by: 4)
        let before = try XCTUnwrap(editor.zone(of: id))
        let glyph = try XCTUnwrap(editor.frame(of: id))
        editor.resizeStickZone(id, horizontally: true, by: 2)
        editor.resizeStickZone(id, horizontally: false, by: 2)
        let after = try XCTUnwrap(editor.zone(of: id))
        XCTAssertEqual(after.x, before.x - 16)
        XCTAssertEqual(after.y, before.y - 16)
        XCTAssertEqual(after.width, before.width + 32)
        XCTAssertEqual(after.height, before.height + 32)
        XCTAssertEqual(editor.frame(of: id), glyph)
        editor.resizeStickZone(id, horizontally: true, by: -2)
        editor.resizeStickZone(id, horizontally: false, by: -2)
        XCTAssertEqual(editor.zone(of: id), before)
    }
}
