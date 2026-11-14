// SPDX-License-Identifier: GPL-3.0-or-later
import HostIOKit
import XCTest
@testable import PlayportKit

/// The layout editor's model (PLA-13, phase 5;
/// LayoutEditor.dc.html) and the game's own copy it saves.
final class LayoutEditorTests: XCTestCase {
    func testApplyingABareProfileStillStoresIndependentCopiesAndUndoRestoresInheritance() throws {
        var profiles = ControlLayoutProfiles()
        profiles.save(0, preset: .gamepad, layout: .gamepad())
        let profile = try XCTUnwrap(profiles[0])
        var outer = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        outer.apply(profile)
        XCTAssertTrue(outer.changed, "an explicit template copy differs from following a default even when positions match")
        let stored = outer.saved(into: nil)
        XCTAssertEqual(stored.layout, .gamepad)
        XCTAssertEqual(stored.layouts[.gamepad], profile.outer.layout)
        outer.undo()
        XCTAssertTrue(outer.saved(into: nil).isEmpty)
        outer.redo()
        XCTAssertEqual(outer.saved(into: nil), stored)
        var inner = LayoutEditor(preset: .gamepad, width: 800, height: 700, expandedControls: true)
        inner.apply(profile)
        let both = inner.saved(into: stored)
        XCTAssertEqual(both.expandedLayouts[.gamepad], profile.inner.layout)
        XCTAssertEqual(both.layouts[.gamepad], profile.outer.layout)
        inner.undo()
        let innerUndone = inner.saved(into: stored)
        XCTAssertTrue(innerUndone.expandedLayouts.isEmpty)
        XCTAssertEqual(innerUndone.layouts[.gamepad], profile.outer.layout)
    }
    func testInnerAndOuterEditsPersistIndependentlyAndUndoMergesOnlyItsDisplay() throws {
        var original = GameControls(layout: .keyboardMouse, layouts: [.keyboardMouse: ControlLayout(controls: [space])])
        original.mouseSensitivity = 2.5
        var inner = LayoutEditor(game: original,
            state: ControlsState.resolve(game: original, defaults: ControlsDefaults(), controllerConnected: false, expanded: true),
            width: 800, height: 700, expandedControls: true)
        inner.select("b"); inner.resize("b", by: 3)
        var draft = inner.saved(into: original)
        XCTAssertEqual(draft.layouts, original.layouts)
        XCTAssertEqual(draft.layout, original.layout)
        XCTAssertEqual(draft.mouseSensitivity, 2.5)
        let innerLayout = try XCTUnwrap(draft.expandedLayouts[.keyboardMouse])
        XCTAssertNotEqual(innerLayout, original.layouts[.keyboardMouse])
        var outer = LayoutEditor(game: original,
            state: ControlsState.resolve(game: original, defaults: ControlsDefaults(), controllerConnected: false), width: 800, height: 400)
        outer.select("b"); outer.resize("b", by: 1)
        draft.copyDisplayLayout(from: outer.saved(into: original), expanded: false)
        XCTAssertEqual(draft.expandedLayouts[.keyboardMouse], innerLayout)
        outer.undo()
        draft.copyDisplayLayout(from: outer.saved(into: original), expanded: false)
        XCTAssertEqual(draft.layouts, original.layouts)
        XCTAssertEqual(draft.expandedLayouts[.keyboardMouse], innerLayout)
        let restored = try JSONDecoder().decode(GameControls.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(restored, draft)
        XCTAssertEqual(ControlsState.resolve(game: restored, defaults: ControlsDefaults(), controllerConnected: false, expanded: true).edited, innerLayout)
        XCTAssertEqual(ControlsState.resolve(game: restored, defaults: ControlsDefaults(), controllerConnected: false).edited, original.layouts[.keyboardMouse])
    }

    func testDualProfilesKeepBothVariantsAndMigrateAnEarlierSingleTemplate() throws {
        let outer = ControlLayoutProfiles.Variant(preset: .keyboardMouse, layout: ControlLayout(controls: [space]))
        var bigger = space; bigger.width = 96; bigger.height = 96
        let inner = ControlLayoutProfiles.Variant(preset: .gamepad, layout: ControlLayout(controls: [bigger]))
        var profiles = ControlLayoutProfiles()
        profiles.save(0, outer: outer, inner: inner)
        let profile = try XCTUnwrap(profiles[0])
        XCTAssertEqual(profile.outer, outer); XCTAssertEqual(profile.inner, inner)
        let restored = try JSONDecoder().decode(ControlLayoutProfiles.self, from: JSONEncoder().encode(profiles))
        XCTAssertEqual(restored, profiles)
        var innerEditor = LayoutEditor(preset: .keyboardMouse, width: 800, height: 700, expandedControls: true)
        innerEditor.apply(profile)
        XCTAssertEqual(innerEditor.preset, .gamepad)
        XCTAssertEqual(innerEditor.layout, inner.layout)
        let layout = try JSONSerialization.jsonObject(with: JSONEncoder().encode(outer.layout))
        let legacy = try JSONSerialization.data(withJSONObject: ["slots": ["0": ["name": "Old", "preset": "keyboardMouse", "layout": layout]]])
        let migrated = try JSONDecoder().decode(ControlLayoutProfiles.self, from: legacy)
        XCTAssertEqual(migrated[0]?.outer, outer)
        XCTAssertEqual(migrated[0]?.inner.layout, outer.layout.sideReachLayout())
    }
    func testExpandedPresetMovesUpperGroupsToSidesWithoutChangingCompactOrCustomLayouts() throws {
        for preset in [OnScreenLayout.gamepad, .keyboardMouse, .pointClick] {
            let state = ControlsState(layout: preset, visible: true, opacity: 0.6)
            let compact = try XCTUnwrap(state.presentationLayout(expanded: false))
            let expanded = try XCTUnwrap(state.presentationLayout(expanded: true))
            for old in compact.controls {
                let new = try XCTUnwrap(expanded.control(old.id))
                XCTAssertEqual(new.actions, old.actions)
                XCTAssertEqual(new.width, old.width)
                XCTAssertEqual(new.height, old.height)
                XCTAssertEqual(new.x, old.x)
                switch old.anchor {
                case .topLeading: XCTAssertEqual(new.anchor, .leading)
                case .topTrailing: XCTAssertEqual(new.anchor, .trailing)
                default: XCTAssertEqual(new, old)
                }
            }
            let custom = ControlsState(layout: preset, visible: true, opacity: 0.6, edited: compact)
            XCTAssertEqual(custom.presentationLayout(expanded: true), compact)
            let editor = LayoutEditor(preset: preset, width: 800, height: 700, expandedControls: true)
            XCTAssertEqual(editor.layout, expanded)
            XCTAssertFalse(editor.isEdited)
            XCTAssertFalse(editor.changed)
            XCTAssertTrue(editor.saved(into: nil).isEmpty, "opening the editor must not freeze the expanded preset into every display")
        }
    }
    func testGroupDragKeepsSpacingAtEdgesAndIsOneUndoStep() throws {
        var other = space; other.id = "other"; other.x = 140
        var e = editor([space, other])
        e.toggleSelection("b"); e.toggleSelection("other")
        let before = e.layout
        let first = try XCTUnwrap(e.frame(of: "b")), second = try XCTUnwrap(e.frame(of: "other"))
        e.drag("b", dx: 80, dy: 32)
        e.drag("other", dx: 10000, dy: 10000)
        e.endGesture()
        let a = try XCTUnwrap(e.frame(of: "b")), b = try XCTUnwrap(e.frame(of: "other"))
        XCTAssertEqual(b.x - a.x, second.x - first.x, accuracy: 0.001)
        XCTAssertLessThanOrEqual(b.x + b.width, 800)
        XCTAssertLessThanOrEqual(b.y + b.height, 400)
        XCTAssertEqual(e.selectedIDs, ["b", "other"])
        e.undo()
        // Changing the drag's originating control starts another gesture.
        e.undo()
        XCTAssertEqual(e.layout, before)
        e.redo(); e.redo()
        XCTAssertEqual(e.frame(of: "other"), b)
    }

    func testGroupResizeScalesSpacingAndLeavesOtherControlsAlone() throws {
        var second = space; second.id = "second"; second.x = 140
        var untouched = space; untouched.id = "untouched"; untouched.x = 300
        var e = editor([space, second, untouched])
        e.select("b"); e.toggleSelection("second")
        let before = e.layout
        e.pinch("second", scale: 2)
        e.endGesture()
        let a = try XCTUnwrap(e.frame(of: "b")), b = try XCTUnwrap(e.frame(of: "second"))
        XCTAssertEqual(a.width, 96, accuracy: 0.001)
        XCTAssertEqual(b.x - a.x, 200, accuracy: 0.001)
        XCTAssertEqual(e.layout.control("untouched"), untouched)
        e.undo(); XCTAssertEqual(e.layout, before)
        e.selectAll(); XCTAssertEqual(e.selectedIDs.count, 3)
        e.select(nil); XCTAssertTrue(e.selectedIDs.isEmpty)
    }

    func testSharedProfilesAreIndependentCopiesAndApplyingCanBeUndone() throws {
        var profiles = ControlLayoutProfiles()
        profiles.save(0, preset: .keyboardMouse, layout: ControlLayout(controls: [space]))
        profiles.rename(0, to: "  Keyboard  ")
        XCTAssertEqual(profiles.name(0), "Keyboard")
        XCTAssertNil(profiles[1]); XCTAssertNil(profiles[2])
        profiles.save(ControlLayoutProfiles.count, preset: .keyboardMouse, layout: ControlLayout(controls: [space]))
        XCTAssertNil(profiles[ControlLayoutProfiles.count])
        let roundTrip = try JSONDecoder().decode(ControlLayoutProfiles.self, from: JSONEncoder().encode(profiles))
        XCTAssertEqual(roundTrip, profiles)
        var a = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        let original = a.layout
        a.apply(try XCTUnwrap(profiles[0]))
        a.undo(); XCTAssertEqual(a.layout, original)
        a.redo(); a.select("b"); a.resize("b", by: 2)
        let saved = a.saved(into: GameControls())
        XCTAssertNotEqual(saved.layouts[.keyboardMouse], profiles[0]?.layout)
        var b = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        b.apply(try XCTUnwrap(profiles[0]))
        XCTAssertEqual(b.layout, ControlLayout(controls: [space]), "another game's copy uses the unchanged shared template")
    }

    func testGroupShrinkingGrowingAndUndoOnFourByThreeCanvas() throws {
        var second = space; second.id = "second"; second.x = 140
        var e = LayoutEditor(preset: .keyboardMouse,
            copies: [.keyboardMouse: ControlLayout(controls: [space, second])],
            width: 800, height: 600, insets: ControlInsets(top: 16, left: 24, bottom: 20, right: 24))
        e.select("b"); e.toggleSelection("second")
        let original = e.layout
        e.resize("second", by: -1)
        XCTAssertLessThan(try XCTUnwrap(e.frame(of: "b")).width, 48)
        e.undo(); XCTAssertEqual(e.layout, original)
        e.pinch("b", scale: 100)
        e.endGesture()
        let a = try XCTUnwrap(e.frame(of: "b")), b = try XCTUnwrap(e.frame(of: "second"))
        XCTAssertGreaterThan(a.width, 48)
        XCTAssertEqual(a.width, b.width, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(a.x, 24)
        XCTAssertLessThanOrEqual(b.x + b.width, 776.001)
        XCTAssertGreaterThanOrEqual(a.y, 16)
        XCTAssertLessThanOrEqual(a.y + a.height, 580.001)
        e.undo(); XCTAssertEqual(e.layout, original)
        e.pinch("second", scale: 0.001)
        e.endGesture()
        XCTAssertEqual(try XCTUnwrap(e.frame(of: "b")).width, LayoutEditor.minimumSide, accuracy: 0.001)
        XCTAssertEqual(e.selectedIDs, ["b", "second"])
        e.undo(); XCTAssertEqual(e.layout, original)
    }
    // MARK: the game's own copy

    func testFiveProfilesExtendExistingSlotsWithoutChangingNamesVariantsOrFutureFields() throws {
        var original = ControlLayoutProfiles()
        for slot in 0..<3 {
            original.save(slot, preset: .keyboardMouse, layout: ControlLayout(controls: [space]))
            original.rename(slot, to: "Existing \(slot)")
        }
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        raw["future"] = ["version": 9]
        var slots = try XCTUnwrap(raw["slots"] as? [String: [String: Any]])
        slots["0"]?["futureProfile"] = "kept"
        var outer = try XCTUnwrap(slots["0"]?["outer"] as? [String: Any])
        var layout = try XCTUnwrap(outer["layout"] as? [String: Any])
        var controls = try XCTUnwrap(layout["controls"] as? [[String: Any]])
        controls[0]["futureControl"] = "kept"
        layout["controls"] = controls; outer["layout"] = layout; slots["0"]?["outer"] = outer
        raw["slots"] = slots
        let data = try JSONSerialization.data(withJSONObject: raw)
        var expanded = try JSONDecoder().decode(ControlLayoutProfiles.self, from: data)
        XCTAssertEqual(ControlLayoutProfiles.count, 5)
        for slot in 3..<5 {
            expanded.save(slot, preset: .gamepad, layout: .gamepad())
            XCTAssertNotNil(expanded[slot]?.outer)
            XCTAssertNotNil(expanded[slot]?.inner)
        }
        for slot in 0..<3 { XCTAssertEqual(expanded[slot], original[slot]) }
        let saved = try expanded.json(preserving: data)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertEqual((object["future"] as? [String: Int])?["version"], 9)
        let savedSlots = try XCTUnwrap(object["slots"] as? [String: [String: Any]])
        XCTAssertEqual(savedSlots["0"]?["futureProfile"] as? String, "kept")
        let savedOuter = try XCTUnwrap(savedSlots["0"]?["outer"] as? [String: Any])
        let savedLayout = try XCTUnwrap(savedOuter["layout"] as? [String: Any])
        let savedControls = try XCTUnwrap(savedLayout["controls"] as? [[String: Any]])
        XCTAssertEqual(savedControls[0]["futureControl"] as? String, "kept")
        XCTAssertEqual(try JSONDecoder().decode(ControlLayoutProfiles.self, from: saved), expanded)
    }

    func testAGamesEditedCopyIsDrawnForItsPresetAndRoundTrips() throws {
        var mine = ControlLayout.keyboardMouse()
        mine.controls.removeAll { $0.id == "tab" }
        let game = GameControls(layout: .keyboardMouse, layouts: [.keyboardMouse: mine])
        let data = try JSONEncoder().encode(game)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil((object["layouts"] as? [String: Any])?["keyboardMouse"])   // keyed by the preset's name
        XCTAssertEqual(try JSONDecoder().decode(GameControls.self, from: data), game)
        XCTAssertFalse(game.isEmpty)

        let d = ControlsDefaults()
        XCTAssertEqual(ControlsState.resolve(game: game, defaults: d, controllerConnected: false).drawnLayout, mine)
        // Another preset chosen: its own layout; the copy is kept for when Keyboard & mouse comes back.
        var other = game
        other.layout = .pointClick
        XCTAssertEqual(ControlsState.resolve(game: other, defaults: d, controllerConnected: false).drawnLayout, .pointClick())
        // Hidden or Off: nothing drawn.
        XCTAssertNil(ControlsState.resolve(game: game, defaults: d, controllerConnected: true).drawnLayout)
    }

    func testRecordsWithoutACopyStillLoadAndOnesWithAnUnreadableCopyAreKeptAsTheyCame() throws {
        // Saved before the editor: no `layouts`.
        XCTAssertEqual(try JSONDecoder().decode(GameControls.self, from: Data(#"{"layout":"gamepad","opacity":0.5}"#.utf8)),
                       GameControls(layout: .gamepad, opacity: 0.5))
        XCTAssertEqual(try JSONEncoder().encode(GameControls(opacity: 0.5)), Data(#"{"opacity":0.5}"#.utf8))
        // A later build's copy (another layout version, or a preset this build lacks) makes the
        // record unreadable here, so it is written back untouched rather than losing the copy.
        let later = #"{"layout":"keyboardMouse","layouts":{"keyboardMouse":{"version":4,"controls":[]}}}"#
        let unknown = #"{"layout":"gamepad","layouts":{"racingWheel":{"version":3,"controls":[]}}}"#
        let good = try String(decoding: JSONEncoder().encode(GameControls(layout: .gamepad, layouts: [.gamepad: .gamepad(dpad: .on)])),
                              as: UTF8.self)
        var r = try XCTUnwrap(GameControlsRecords(json: Data(#"{"app-1":\#(later),"app-2":\#(unknown),"app-3":\#(good)}"#.utf8)))
        XCTAssertEqual(Set(r.unreadable.keys), ["app-1", "app-2"])
        XCTAssertEqual(r["app-3"]?.layouts[.gamepad], .gamepad(dpad: .on))
        r.set("app-4", GameControls(opacity: 0.3))
        let again = try XCTUnwrap(GameControlsRecords(json: r.json()))
        XCTAssertEqual(again.unreadable, r.unreadable)
        XCTAssertEqual(again["app-3"], r["app-3"])
        // Off has no layout to copy.
        XCTAssertThrowsError(try JSONDecoder().decode(GameControls.self,
                                                      from: Data(#"{"layouts":{"off":{"version":3,"controls":[]}}}"#.utf8)))
    }

    // MARK: the editor

    /// One 48 pt button centred 40 pt from the top left, alone in an 800 × 400 view.
    let space = Control(id: "b", actions: [.key(0x20, [])], label: "Space", anchor: .topLeading, x: 40, y: 40, width: 48, height: 48)
    func editor(_ controls: [Control], width: Double = 800, height: Double = 400, insets: ControlInsets = .zero) -> LayoutEditor {
        LayoutEditor(preset: .keyboardMouse, copies: [.keyboardMouse: ControlLayout(controls: controls)], width: width, height: height,
                     insets: insets)
    }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> TouchRect { TouchRect(x: x, y: y, width: w, height: h) }

    func testADragSnapsToTheGridIsOneUndoStepAndReanchorsTheControl() throws {
        var e = editor([space])
        XCTAssertEqual(e.frame(of: "b"), rect(16, 16, 48, 48))
        e.drag("b", dx: 13, dy: 5)
        XCTAssertEqual(e.frame(of: "b"), rect(32, 24, 48, 48))   // 29, 21 to the 8 pt grid
        XCTAssertEqual(e.guides, [])
        XCTAssertEqual(e.selection, "b")
        XCTAssertFalse(e.canUndo)                               // not until the gesture ends
        e.drag("b", dx: 600, dy: 300)                            // the same drag, further
        XCTAssertEqual(e.frame(of: "b"), rect(616, 320, 48, 48))
        // Its centre (640, 344) is in the lower right ninth: anchored there, so it keeps that corner on other iPhones.
        let moved = try XCTUnwrap(e.layout.control("b"))
        XCTAssertEqual([moved.anchor.rawValue, "\(moved.x)", "\(moved.y)"], ["bottomTrailing", "-160.0", "-56.0"])
        e.endGesture()
        XCTAssertTrue(e.canUndo)
        e.undo()
        XCTAssertEqual(e.layout.control("b"), space)
        XCTAssertTrue(e.canRedo)
        e.redo()
        XCTAssertEqual(e.layout.control("b"), moved)
        e.undo()
        e.resize("b", by: 1)                                     // a new edit drops the redo
        XCTAssertFalse(e.canRedo)
    }

    func testADragSnapsToAnotherControlsOrTheSafeAreasLinesWithAGuide() {
        let other = Control(id: "a", actions: [.key(0x41, [])], label: "A", anchor: .topLeading, x: 100, y: 100, width: 40, height: 40)
        var e = editor([other, space])
        // Left 79 is 1 pt from the other's left (80); centre 103 is 3 from its centre: the nearest wins.
        e.drag("b", dx: 63, dy: 0)
        XCTAssertEqual(e.frame(of: "b"), rect(80, 16, 48, 48))
        XCTAssertEqual(e.guides, [.vertical(x: 80)])
        e.endGesture()
        XCTAssertEqual(e.guides, [])
        // The safe area's middle line (centre 397 → 400), and the other's bottom (centre 117 → 120).
        e.drag("b", dx: 293, dy: 77)                             // left 373, centre 397; top 93, middle 117, bottom 141
        XCTAssertEqual(e.frame(of: "b"), rect(376, 96, 48, 48))
        XCTAssertEqual(e.guides, [.vertical(x: 400), .horizontal(y: 120)])
    }

    func testADragStaysInTheSafeAreaAndTheGridStartsAtItsCorner() throws {
        var e = editor([space], width: 844, height: 390, insets: ControlInsets(left: 47, bottom: 21, right: 47))
        XCTAssertEqual(e.frame(of: "b"), rect(63, 16, 48, 48))
        e.drag("b", dx: -500, dy: -500)
        XCTAssertEqual(e.frame(of: "b"), rect(47, 0, 48, 48))
        e.endGesture()
        e.drag("b", dx: 10, dy: 3)                               // 57: the grid from 47 makes it 55
        XCTAssertEqual(e.frame(of: "b"), rect(55, 0, 48, 48))
        let c = try XCTUnwrap(e.layout.control("b"))
        XCTAssertEqual([c.x, c.y], [32, 24])
    }

    func testAFloatingSticksZoneMovesWithIt() throws {
        var e = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        let f0 = try XCTUnwrap(e.frame(of: "move")), z0 = try XCTUnwrap(e.zone(of: "move"))
        XCTAssertEqual(z0, rect(0, 274, 210, 126))
        e.drag("move", dx: 300, dy: -100)
        e.endGesture()
        let f = try XCTUnwrap(e.frame(of: "move")), z = try XCTUnwrap(e.zone(of: "move"))
        XCTAssertEqual(f.x, 348)                                 // its centre on the safe area's middle line
        XCTAssertEqual(rect(z.x - z0.x, z.y - z0.y, z.width, z.height), rect(f.x - f0.x, f.y - f0.y, 210, 126))
        XCTAssertNil(e.layout.problem)
        XCTAssertEqual(try JSONDecoder().decode(ControlLayout.self, from: JSONEncoder().encode(e.layout)), e.layout)
    }

    func testAPinchResizesToTheGridAboutTheCentreAndSurfacesStayPut() {
        var e = editor([space])
        e.pinch("b", scale: 1.4)                                 // 67.2: 64
        XCTAssertEqual(e.frame(of: "b"), rect(8, 8, 64, 64))
        e.pinch("b", scale: 0.1)                                 // never under 24
        XCTAssertEqual(e.frame(of: "b"), rect(28, 28, 24, 24))
        e.endGesture()
        e.undo()                                                 // the whole pinch at once
        XCTAssertEqual(e.layout.control("b"), space)

        var kbm = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        kbm.drag("look", dx: 100, dy: 100)
        kbm.pinch("look", scale: 0.5)
        kbm.endGesture()
        XCTAssertEqual(kbm.layout, .keyboardMouse())
        XCTAssertFalse(kbm.canUndo)
        kbm.resize("look", by: -2)
        XCTAssertEqual(kbm.layout, .keyboardMouse())
    }

    func testTheInspectorsSizeStepsByTheGrid() {
        var e = editor([space, Control(id: "esc", actions: [.key(0x1B, [])], label: "Esc", anchor: .topLeading, x: 30, y: 22,
                                       width: 52, height: 30)])
        e.resize("b", by: 1)
        XCTAssertEqual(e.frame(of: "b"), rect(12, 12, 56, 56))
        XCTAssertEqual(e.details("b")?.size, "56 pt")
        e.resize("esc", by: -1)                                  // 44 × 22: no side under 24
        XCTAssertEqual(e.details("esc")?.size, "44 × 24 pt")
        e.undo()
        XCTAssertEqual(e.details("esc")?.size, "52 × 30 pt")
    }

    func testAddOffersWhatTheLayoutCanTakeAndPlacesItInTheMiddle() throws {
        var kbm = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        XCTAssertEqual(kbm.addable, [.button, .stick, .keyStick, .dpad, .keyboard])   // a look area already; no pointer for tools
        XCTAssertEqual(kbm.add(.button), "button")
        XCTAssertEqual(kbm.selection, "button")
        let b = try XCTUnwrap(kbm.layout.control("button"))
        XCTAssertEqual(b.actions, [.key(0x20, [])])
        XCTAssertEqual(b.label, "Space")
        XCTAssertEqual(kbm.frame(of: "button"), rect(372, 172, 56, 56))   // centred in the safe area
        XCTAssertEqual(kbm.add(.button), "button-2")
        XCTAssertEqual(kbm.add(.keyboard), "keyboard-2")
        XCTAssertEqual(kbm.layout.control("keyboard-2")?.actions, [.playport(.keyboard)])
        XCTAssertNil(kbm.add(.pointer))
        XCTAssertNil(kbm.layout.problem)
        kbm.undo(); kbm.undo(); kbm.undo()
        XCTAssertEqual(kbm.layout, .keyboardMouse())

        var pc = LayoutEditor(preset: .pointClick, width: 800, height: 400)
        XCTAssertFalse(pc.addable.contains(.hover))              // each tool once
        pc.remove("hover")
        XCTAssertTrue(pc.addable.contains(.hover))
        XCTAssertEqual(pc.add(.hover), "hover")
        XCTAssertEqual(pc.layout.control("hover")?.tool, .hover)
        XCTAssertNil(pc.layout.problem)

        var pad = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        XCTAssertEqual(pad.add(.button).flatMap { pad.layout.control($0) }?.actions, [.pad(.a)])
        XCTAssertEqual(pad.add(.stick), "rightStick")            // the left one is there
        XCTAssertFalse(pad.addable.contains(.stick))
        XCTAssertEqual(pad.add(.dpad).flatMap { pad.layout.control($0) }?.actions, [.pad(.up), .pad(.down), .pad(.left), .pad(.right)])
        XCTAssertEqual(pad.add(.lookArea), "look")
        XCTAssertEqual(pad.layout.controls.first?.id, "look")    // under everything
        XCTAssertFalse(pad.addable.contains(.pointer))           // one surface
        XCTAssertNil(pad.layout.problem)
        XCTAssertEqual(pad.layout.targets(width: 800, height: 400).first?.kind, .look)
    }

    func testDuplicateAndRemove() throws {
        var e = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        let jump = try XCTUnwrap(e.frame(of: "jump"))
        XCTAssertEqual(e.duplicate("jump"), "jump-2")
        XCTAssertEqual(e.selection, "jump-2")
        XCTAssertEqual(e.frame(of: "jump-2"), rect(jump.x + 16, jump.y + 16, 56, 56))
        XCTAssertEqual(e.layout.control("jump-2")?.actions, [.key(0x20, [])])
        XCTAssertEqual(e.layout.controls.map(\.id).firstIndex(of: "jump-2"), e.layout.controls.map(\.id).firstIndex(of: "jump")! + 1)
        XCTAssertEqual(e.duplicate("jump-2"), "jump-3")
        XCTAssertNil(e.duplicate("look"))
        let z = try XCTUnwrap(e.zone(of: "move"))
        let copy = try XCTUnwrap(e.duplicate("move"))
        XCTAssertEqual(e.zone(of: copy), rect(z.x + 16, z.y, 210, 126))   // kept in the safe area: no lower
        XCTAssertNil(e.layout.problem)
        e.remove("move-2")
        XCTAssertNil(e.selection)
        e.remove("jump")
        XCTAssertNil(e.layout.control("jump"))
        e.undo()
        XCTAssertNotNil(e.layout.control("jump"))
    }

    /// What a layout has once is not duplicated: a pad stick, each pointer tool (as Add offers them).
    func testDuplicateKeepsTheOneOfEachLimits() {
        var pad = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        XCTAssertNil(pad.duplicate("leftStick"))
        XCTAssertEqual(pad.details("leftStick")?.duplicable, false)
        XCTAssertEqual(pad.details("leftStick")?.movable, true)
        XCTAssertEqual(pad.details("a")?.duplicable, true)
        XCTAssertEqual(pad.layout.controls.filter { $0.kind == .stick }.count, 1)
        var point = LayoutEditor(preset: .pointClick, width: 800, height: 400)
        XCTAssertNil(point.duplicate("hover"))
        XCTAssertNil(point.duplicate("mode"))
        XCTAssertEqual(point.details("hover")?.duplicable, false)
        XCTAssertFalse(point.canUndo)
        // A W A S D stick is any number of key sticks.
        var kbm = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        XCTAssertEqual(kbm.details("move")?.duplicable, true)
        XCTAssertEqual(kbm.duplicate("move"), "move-2")
    }

    /// Add, Duplicate, Remove, Reset and another preset during a drag end the drag first: the drag is
    /// its own undo step, and the next drag starts from where the control is, not the old frame.
    func testAnOperationDuringADragEndsItFirst() throws {
        var e = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        e.drag("jump", dx: -40, dy: 0)
        let moved = try XCTUnwrap(e.frame(of: "jump"))
        e.remove("esc")
        e.drag("jump", dx: 0, dy: 0)
        XCTAssertEqual(e.frame(of: "jump"), moved)
        e.endGesture()
        e.undo()                                                 // the remove
        XCTAssertNotNil(e.layout.control("esc"))
        XCTAssertEqual(e.frame(of: "jump"), moved)
        e.undo()                                                 // the drag
        XCTAssertEqual(e.layout, .keyboardMouse())

        // Reset during a drag: the reset layout, the drag undone after the reset.
        e.drag("jump", dx: -40, dy: 0)
        e.reset()
        XCTAssertNil(e.gesture)
        XCTAssertEqual(e.layout, .keyboardMouse())
        e.undo()
        XCTAssertEqual(e.frame(of: "jump"), moved)
        let ops: [(inout LayoutEditor) -> Void] = [{ _ = $0.add(.button) }, { _ = $0.duplicate("fire") }, { $0.start(from: .pointClick) }]
        for op in ops {
            var o = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
            o.drag("jump", dx: -40, dy: 0)
            op(&o)
            XCTAssertNil(o.gesture)
            o.undo(); o.undo()
            XCTAssertEqual(o.layout, .keyboardMouse())
            XCTAssertFalse(o.canUndo)
        }
    }

    func testTheInspectorEditsWhatAControlPressesItsLabelAndBehaviour() throws {
        var e = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        XCTAssertEqual(e.details("jump"), ControlDetails(id: "jump", label: "Jump", subtitle: "Button · right side", slots: ["Presses"],
                                                         actions: ["Space"], size: "56 pt", behaviour: .hold, movable: true,
                                                         duplicable: true))
        XCTAssertEqual(e.details("move")?.slots, ["Up", "Down", "Left", "Right"])
        XCTAssertEqual(e.details("move")?.actions, ["W", "S", "A", "D"])
        XCTAssertEqual(e.details("move")?.subtitle, "Stick · left side")
        XCTAssertEqual(e.details("look")?.slots, [])
        XCTAssertEqual(e.details("look")?.movable, false)
        XCTAssertNil(e.details("move")?.behaviour)

        // The ActionPicker gets what the slot takes: a button no stick and no mouse look.
        let jump = try XCTUnwrap(e.picker("jump", slot: 0))
        XCTAssertEqual(jump.title, "What Jump presses")
        XCTAssertEqual(jump.cell?.id, "key:0x20")
        var mouse = jump
        mouse.select(.mouse)
        XCTAssertFalse(mouse.rows.flatMap { $0 }.map(\.id).contains("mouse:move"))
        XCTAssertEqual(e.picker("move", slot: 0)?.title, "What WASD up presses")
        XCTAssertNil(e.picker("look", slot: 0))
        XCTAssertNil(e.picker("jump", slot: 1))
        let pad = LayoutEditor(preset: .gamepad, width: 800, height: 400)
        let stick = try XCTUnwrap(pad.picker("leftStick", slot: 0))
        XCTAssertEqual(stick.tabs, [.controller, .playport])
        XCTAssertEqual(stick.rows.map { $0.map(\.id) }, [["pad:leftStick", "pad:rightStick"]])

        e.setAction("jump", slot: 0, .key(0x45, []))
        XCTAssertEqual(e.layout.control("jump")?.actions, [.key(0x45, [])])
        XCTAssertEqual(e.layout.control("jump")?.label, "Jump")  // a label of its own stays
        e.add(.button)
        e.setAction("button", slot: 0, .key(0x46, [.shift]))
        XCTAssertEqual(e.layout.control("button")?.label, "Shift+F")   // its action's name follows
        e.setAction("move", slot: 2, .key(0x25, []))
        XCTAssertEqual(e.layout.control("move")?.actions[2], .key(0x25, []))
        let steps = e
        e.setAction("jump", slot: 0, nil)                        // Nothing: a button keeps its action
        e.setAction("jump", slot: 0, .mouse(.move))
        e.setAction("move", slot: 0, .pad(.leftStick))
        XCTAssertEqual(e, steps)

        e.setLabel("jump", "Hop")
        e.setBehaviour("jump", .toggle)
        e.setBehaviour("move", .toggle)                          // a stick has none
        XCTAssertEqual(e.layout.control("jump")?.label, "Hop")
        XCTAssertEqual(e.layout.control("jump")?.behaviour, .toggle)
        XCTAssertEqual(e.layout.control("move")?.behaviour, .hold)
        XCTAssertNil(e.layout.problem)
        e.undo(); e.undo()
        XCTAssertEqual(e.layout.control("jump")?.label, "Jump")
        XCTAssertEqual(e.layout.control("jump")?.behaviour, .hold)
    }

    func testATapPicksTheTopControlAndTheSurfaceOnlyWhereNothingElseIs() {
        let e = LayoutEditor(preset: .keyboardMouse, width: 800, height: 400)
        XCTAssertEqual(e.control(atX: 729, y: 234), "jump")
        XCTAssertEqual(e.control(atX: 400, y: 100), "look")
        XCTAssertEqual(e.control(atX: 742, y: 325), "fire")
    }

    func testResetStartFromAPresetAndTheSavedCopy() throws {
        var mine = ControlLayout.keyboardMouse()
        mine.controls.removeAll { $0.id == "tab" }
        let pad = ControlLayout.gamepad(dpad: .on)
        let game = GameControls(layout: .keyboardMouse, opacity: 0.5, layouts: [.keyboardMouse: mine, .gamepad: pad])
        let state = ControlsState.resolve(game: game, defaults: ControlsDefaults(), controllerConnected: false)
        var e = LayoutEditor(game: game, state: state, width: 800, height: 400)
        XCTAssertEqual(e.preset, .keyboardMouse)
        XCTAssertEqual(e.layout, mine)                           // the game's copy
        XCTAssertTrue(e.isEdited)
        e.reset()
        XCTAssertEqual(e.layout, .keyboardMouse())
        XCTAssertFalse(e.isEdited)
        // Done after Reset: no copy of Keyboard & mouse; the Gamepad copy is untouched.
        XCTAssertEqual(e.saved(into: game), GameControls(layout: .keyboardMouse, opacity: 0.5, layouts: [.gamepad: pad]))
        e.undo()
        XCTAssertEqual(e.layout, mine)

        e.start(from: .pointClick)
        XCTAssertEqual([e.preset], [.pointClick])
        XCTAssertEqual(e.layout, .pointClick())
        e.start(from: .gamepad)                                  // the game's own copy of it
        XCTAssertEqual(e.layout, pad)
        e.start(from: .off)
        XCTAssertEqual(e.preset, .gamepad)
        e.undo(); e.undo()
        XCTAssertEqual(e.preset, .keyboardMouse)
        XCTAssertEqual(e.layout, mine)

        // Done after an edit: the preset chosen, this copy saved, and the game then draws it.
        e.remove("esc")
        let saved = e.saved(into: game)
        XCTAssertEqual(saved.layout, .keyboardMouse)
        XCTAssertEqual(saved.layouts[.keyboardMouse], e.layout)
        XCTAssertEqual(saved.layouts[.gamepad], pad)
        XCTAssertEqual(ControlsState.resolve(game: saved, defaults: ControlsDefaults(), controllerConnected: false).drawnLayout, e.layout)
        var records = GameControlsRecords()
        records.set("app-1", saved)
        XCTAssertEqual(GameControlsRecords(json: try records.json())?["app-1"], saved)

        // A game with nothing set, its controls Off by default: the editor starts from Gamepad with the
        // default options, and Done unedited changes nothing (the game stays Off).
        let never = ControlsState.resolve(game: nil, defaults: ControlsDefaults(show: .never, dpad: .on), controllerConnected: false)
        var fresh = LayoutEditor(game: nil, state: never, width: 800, height: 400)
        XCTAssertEqual(fresh.preset, .gamepad)
        XCTAssertEqual(fresh.layout, .gamepad(dpad: .on))
        XCTAssertFalse(fresh.isEdited)
        XCTAssertFalse(fresh.changed)
        XCTAssertEqual(fresh.saved(into: nil), GameControls())
        // An edit chooses the preset; undone, nothing is saved again.
        fresh.remove("menu")
        XCTAssertTrue(fresh.changed)
        XCTAssertEqual(fresh.saved(into: nil).layout, .gamepad)
        fresh.undo()
        XCTAssertEqual(fresh.saved(into: nil), GameControls())
    }

    /// Done with nothing changed leaves the game as it was: not pinned to the layout it was following
    /// (Settings' or the suggestion's), its copies as they were. Another preset chosen is saved.
    func testDoneWithNothingChangedLeavesTheGameAsItWas() {
        let game = GameControls(opacity: 0.5)
        let kbm = ControlsState.resolve(game: game, defaults: ControlsDefaults(startingLayout: .keyboardMouse),
                                        controllerConnected: false)
        var e = LayoutEditor(game: game, state: kbm, width: 800, height: 400)
        XCTAssertEqual(e.saved(into: game), game)
        e.start(from: .pointClick)
        e.start(from: .keyboardMouse)                            // back where it began: nothing chosen
        XCTAssertFalse(e.changed)
        XCTAssertEqual(e.saved(into: game), game)
        e.start(from: .pointClick)
        XCTAssertEqual(e.saved(into: game), GameControls(layout: .pointClick, opacity: 0.5))
    }
}
