// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
import HostIOKit
@testable import PlayportKit

final class DisplayLayoutCopyTests: XCTestCase {
    func testUniformScalingIncludesSpacingAndZonesWithoutStretchingSurfaces() throws {
        var source = ControlLayout.keyboardMouse()
        source.referenceSize = .init(width: 1000, height: 800)
        let original = source
        let target = source.copied(to: .init(width: 500, height: 300))
        let scale = 0.375
        for c in original.controls {
            let copy = try XCTUnwrap(target.control(c.id))
            XCTAssertEqual(copy.actions, c.actions)
            XCTAssertEqual(copy.behaviour, c.behaviour)
            XCTAssertEqual(copy.label, c.label)
            XCTAssertEqual(copy.anchor, c.anchor)
            if c.isSurface { XCTAssertEqual(copy, c); continue }
            XCTAssertEqual(copy.width, c.width * scale, accuracy: 0.00001)
            XCTAssertEqual(copy.height, c.height * scale, accuracy: 0.00001)
            XCTAssertEqual(copy.x, c.x * scale, accuracy: 0.00001)
            XCTAssertEqual(copy.y, c.y * scale, accuracy: 0.00001)
            if let zone = c.floatingZone {
                let copiedZone = try XCTUnwrap(copy.floatingZone)
                XCTAssertEqual(copiedZone.width, zone.width * scale, accuracy: 0.00001)
                XCTAssertEqual(copiedZone.height, zone.height * scale, accuracy: 0.00001)
                XCTAssertEqual(copiedZone.x, zone.x * scale, accuracy: 0.00001)
                XCTAssertEqual(copiedZone.y, zone.y * scale, accuracy: 0.00001)
            }
        }
        XCTAssertEqual(source, original)
        XCTAssertNil(target.problem)
        let look = try XCTUnwrap(target.control("look"))
        XCTAssertEqual(look.frame(width: 500, height: 300), TouchRect(x: 0, y: 0, width: 500, height: 300))
    }

    func testBothDirectionsAreIndependentAndUndoRestoresOnlyTarget() throws {
        for expanded in [false, true] {
            var source = LayoutEditor(preset: .keyboardMouse, width: 1000, height: 800, expandedControls: !expanded)
            source.resize("jump", by: 2)
            let original = source.layout
            var target = LayoutEditor(preset: .gamepad, width: 540, height: 340,
                insets: .init(top: 10, left: 20, bottom: 30, right: 20), expandedControls: expanded)
            let before = target.layout
            target.copyDisplayLayout(preset: source.preset, layout: source.layout)
            let copied = target.layout
            XCTAssertEqual(copied.referenceSize, .init(width: 500, height: 300))
            XCTAssertEqual(try XCTUnwrap(target.frame(of: "jump")).width,
                           try XCTUnwrap(source.frame(of: "jump")).width * 0.375, accuracy: 0.00001)
            target.undo(); XCTAssertEqual(target.layout, before)
            XCTAssertFalse(target.changed)
            target.redo(); XCTAssertEqual(target.layout, copied)
            target.resize("jump", by: 1)
            XCTAssertEqual(source.layout, original)
            let sourceSaved = source.saved(into: nil)
            let saved = target.saved(into: sourceSaved)
            XCTAssertEqual(expanded ? saved.layouts : saved.expandedLayouts,
                           expanded ? sourceSaved.layouts : sourceSaved.expandedLayouts)
            XCTAssertEqual(try JSONDecoder().decode(GameControls.self, from: JSONEncoder().encode(saved)), saved)
            var profiles = ControlLayoutProfiles()
            let a = ControlLayoutProfiles.Variant(preset: source.preset, layout: original)
            let b = ControlLayoutProfiles.Variant(preset: target.preset, layout: target.layout)
            profiles.save(0, outer: expanded ? a : b, inner: expanded ? b : a)
            let restored = try JSONDecoder().decode(ControlLayoutProfiles.self, from: profiles.json(preserving: nil))
            XCTAssertEqual(restored, profiles)
            target.remove("jump")
            XCTAssertNotNil(expanded ? restored[0]?.inner.layout.control("jump") : restored[0]?.outer.layout.control("jump"))
        }
    }

    func testLegacyCopiesSupportKnownCanvasOrExplicitOriginalSize() throws {
        let source = ControlLayout.pointClick()
        let decoded = try JSONDecoder().decode(ControlLayout.self, from: JSONEncoder().encode(source))
        XCTAssertNil(decoded.referenceSize)
        let unscaled = decoded.copied(to: .init(width: 500, height: 300))
        XCTAssertEqual(unscaled.controls, source.controls)
        XCTAssertEqual(unscaled.referenceSize, .init(width: 500, height: 300))
        let scaled = decoded.copied(to: .init(width: 500, height: 300), from: .init(width: 1000, height: 600))
        XCTAssertEqual(try XCTUnwrap(scaled.control("keyboard")).width, 22)
        XCTAssertEqual(decoded, source)
        XCTAssertEqual(source.copied(to: .init(width: 0, height: 300)), source)
    }

    func testInheritedInnerLayoutDoesNotBorrowOuterCanvasDimensions() {
        var outer = ControlLayout.keyboardMouse()
        outer.referenceSize = .init(width: 800, height: 400)
        XCTAssertNil(outer.sideReachLayout().referenceSize)
        XCTAssertEqual(outer.referenceSize, .init(width: 800, height: 400))
    }

    func testReplacingAProfileClearsObsoleteReferenceSize() throws {
        var layout = ControlLayout.keyboardMouse()
        layout.referenceSize = .init(width: 1000, height: 800)
        var profiles = ControlLayoutProfiles()
        profiles.save(0, preset: .keyboardMouse, layout: layout)
        let original = try profiles.json(preserving: nil)
        profiles.save(0, preset: .keyboardMouse, layout: .keyboardMouse())
        let restored = try JSONDecoder().decode(ControlLayoutProfiles.self, from: profiles.json(preserving: original))
        XCTAssertNil(restored[0]?.outer.layout.referenceSize)
        XCTAssertNil(restored[0]?.inner.layout.referenceSize)
    }

    func testCopiesOfBarePresetsAreExplicitAndReferenceSizeDoesNotMakeAPresetEdited() throws {
        var target = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        target.copyDisplayLayout(preset: .gamepad, layout: .gamepad())
        XCTAssertFalse(target.isEdited)
        XCTAssertTrue(target.changed)
        XCTAssertNotNil(target.saved(into: nil).layouts[.gamepad])
        target.undo()
        XCTAssertTrue(target.saved(into: nil).isEmpty)
    }

    func testCopyFromLargerDisplayKeepsAllTargetsInsideSafeArea() {
        var source = ControlLayout.gamepad(dpad: .on, rightStick: .above)
        source.referenceSize = .init(width: 1200, height: 900)
        let copy = source.copied(to: .init(width: 420, height: 240))
        let insets = ControlInsets(top: 12, left: 20, bottom: 16, right: 30)
        for target in copy.targets(width: 470, height: 268, insets: insets) {
            XCTAssertGreaterThanOrEqual(target.frame.x, 20)
            XCTAssertGreaterThanOrEqual(target.frame.y, 12)
            XCTAssertLessThanOrEqual(target.frame.maxX, 440.00001)
            XCTAssertLessThanOrEqual(target.frame.maxY, 252.00001)
        }
    }
}
