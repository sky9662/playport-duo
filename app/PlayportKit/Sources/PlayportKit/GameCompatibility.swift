// SPDX-License-Identifier: GPL-3.0-or-later
/// First-class release options. Nil follows the next level; OpenGL nil keeps the title profile.
public struct GameCompatibility: Codable, Equatable, Sendable {
    public var cursor: Bool?
    public var sharedImage: Bool?
    public var openGL41: Bool?
    public init(cursor: Bool? = nil, sharedImage: Bool? = nil, openGL41: Bool? = nil) {
        self.cursor = cursor; self.sharedImage = sharedImage; self.openGL41 = openGL41
    }
    public var isEmpty: Bool { cursor == nil && sharedImage == nil && openGL41 == nil }
    /// Explicit Off also removes inherited shared-file and process environment overrides.
    public var configRemovals: Set<String> {
        openGL41 == false ? ["env.MESA_GL_VERSION_OVERRIDE", "env.MESA_GLSL_VERSION_OVERRIDE"] : []
    }
    public func over(_ base: GameCompatibility) -> GameCompatibility {
        GameCompatibility(cursor: cursor ?? base.cursor, sharedImage: sharedImage ?? base.sharedImage,
                          openGL41: openGL41 ?? base.openGL41)
    }
    /// Apply last, including explicit removal of profile flags, after release filtering and title keys.
    public func applying(to config: [String: String]) -> [String: String] {
        var result = config
        if let sharedImage { result["env.PLAYPORT_SMALL_SHARED_IMAGE"] = sharedImage ? "1" : "0" }
        if let openGL41 {
            result["env.MESA_GL_VERSION_OVERRIDE"] = openGL41 ? "4.1" : nil
            result["env.MESA_GLSL_VERSION_OVERRIDE"] = openGL41 ? "410" : nil
        }
        return result
    }
}
