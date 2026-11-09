// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest
@testable import PlayportKit

final class GameCompatibilityTests: XCTestCase {
    func testReleaseFilteringPreservesChoicesAndRemovesProfileFlags() throws {
        let profile = LaunchSettings(runtime: "env.MESA_GL_VERSION_OVERRIDE=4.1 env.MESA_GLSL_VERSION_OVERRIDE=410")
        let global = LaunchSettings(compatibility: GameCompatibility(cursor: false, sharedImage: false, openGL41: false))
        var effective = LaunchSettings.resolve(game: profile, global: global)
        effective.runtime = LaunchSettings.releaseRuntime(compat: profile)
        let config = effective.config(over: ["env.MESA_GL_VERSION_OVERRIDE": "4.6"])
        XCTAssertNil(config["env.MESA_GL_VERSION_OVERRIDE"])
        XCTAssertNil(config["env.MESA_GLSL_VERSION_OVERRIDE"])
        XCTAssertEqual(config["env.PLAYPORT_SMALL_SHARED_IMAGE"], "0")
        XCTAssertEqual(effective.compatibility.cursor, false)
        var own = LaunchSettings(compatibility: GameCompatibility(sharedImage: true, openGL41: true))
        own = own.over(profile)
        effective = LaunchSettings.resolve(game: own, global: global)
        effective.runtime = LaunchSettings.releaseRuntime(compat: profile)
        XCTAssertEqual(effective.config(over: [:])["env.PLAYPORT_SMALL_SHARED_IMAGE"], "1")
        XCTAssertEqual(effective.config(over: [:])["env.MESA_GL_VERSION_OVERRIDE"], "4.1")
        XCTAssertEqual(effective.config(over: [:])["env.MESA_GLSL_VERSION_OVERRIDE"], "410")
        XCTAssertEqual(effective.compatibility.cursor, false)
        let restored = try JSONDecoder().decode(LaunchSettings.self, from: JSONEncoder().encode(own))
        XCTAssertEqual(restored.compatibility, own.compatibility)
        XCTAssertFalse(restored.isEmpty)
    }
    func testOldDefaultsKeepProfileUntouched() throws {
        let old = try JSONDecoder().decode(LaunchSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.isEmpty)
        let config = ["env.MESA_GL_VERSION_OVERRIDE": "4.1", "env.MESA_GLSL_VERSION_OVERRIDE": "410"]
        XCTAssertEqual(old.compatibility.applying(to: config), config)
        XCTAssertTrue(old.compatibility.configRemovals.isEmpty)
    }

    func testExplicitOffRemovesInheritedOverridesWithoutEditingSharedFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = "# env.MESA_GL_VERSION_OVERRIDE = keep comment\n env.MESA_GL_VERSION_OVERRIDE = 4.6\nenv.MESA_GL_VERSION_OVERRIDE=4.1\nenv.MESA_GLSL_VERSION_OVERRIDE = 410\njumbo-mb = 1024\nenv.OTHER = keep\n"
        let shared = root.appendingPathComponent(TitleConfig.fileName)
        try Data(original.utf8).write(to: shared)
        let config = ["env.MESA_GL_VERSION_OVERRIDE": "4.5", "env.EXTRA": "yes"]
        let removals = GameCompatibility(openGL41: false).configRemovals
        let dir = try TitleConfig.prepare(shared: root, documents: root, exe: "Games/Test/game.exe",
                                         config: config, title: "Test", removing: removals)
        let copy = try String(contentsOf: dir.appendingPathComponent(TitleConfig.fileName), encoding: .utf8)
        XCTAssertTrue(copy.contains("# env.MESA_GL_VERSION_OVERRIDE = keep comment"))
        XCTAssertFalse(copy.contains(" = 4.6"))
        XCTAssertFalse(copy.contains("OVERRIDE=4.1"))
        XCTAssertFalse(copy.contains("OVERRIDE = 410"))
        XCTAssertFalse(copy.contains(" = 4.5"))
        XCTAssertTrue(copy.contains("jumbo-mb = 1024"))
        XCTAssertTrue(copy.contains("env.OTHER = keep"))
        XCTAssertTrue(copy.contains("env.EXTRA = yes"))
        XCTAssertEqual(try Data(contentsOf: shared), Data(original.utf8))
        XCTAssertTrue(TitleConfig.merged(shared: original, config: [:], title: "Test").contains("OVERRIDE=4.1"))
        XCTAssertTrue(GameCompatibility(openGL41: true).configRemovals.isEmpty)
    }
}
