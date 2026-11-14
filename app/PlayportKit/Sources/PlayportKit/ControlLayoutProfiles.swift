// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Five shared layout templates. Applying one copies it into the game's
/// editor; later game edits never mutate the shared template.
public struct ControlLayoutProfiles: Codable, Equatable, Sendable {
    public struct Variant: Codable, Equatable, Sendable {
        public var preset: OnScreenLayout
        public var layout: ControlLayout
        public init(preset: OnScreenLayout, layout: ControlLayout) { self.preset = preset; self.layout = layout }
    }
    public struct Profile: Codable, Equatable, Sendable {
        public var name: String
        public var outer: Variant
        public var inner: Variant
        public var preset: OnScreenLayout { outer.preset }
        public var layout: ControlLayout { outer.layout }
        init(name: String, outer: Variant, inner: Variant) { self.name = name; self.outer = outer; self.inner = inner }
        enum CodingKeys: String, CodingKey { case name, outer, inner, preset, layout }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            if let value = try c.decodeIfPresent(Variant.self, forKey: .outer) { outer = value }
            else { outer = Variant(preset: try c.decode(OnScreenLayout.self, forKey: .preset), layout: try c.decode(ControlLayout.self, forKey: .layout)) }
            inner = try c.decodeIfPresent(Variant.self, forKey: .inner)
                ?? Variant(preset: outer.preset, layout: outer.layout.sideReachLayout())
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name); try c.encode(outer, forKey: .outer); try c.encode(inner, forKey: .inner)
        }
    }
    public static let storageKey = "controls.layoutProfiles"
    public static let count = 5
    private var slots: [String: Profile] = [:]
    public init() {}
    /// Preserve fields from newer versions when updating a known template.
    /// Controls match by stable ID so removing one does not resurrect it.
    public func json(preserving original: Data?) throws -> Data {
        let current = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self))
        func merge(_ old: Any?, _ new: Any) -> Any {
            if let previous = old as? [[String: Any]], let updates = new as? [[String: Any]],
               updates.allSatisfy({ $0["id"] is String }) {
                return updates.map { value in
                    merge(previous.first { ($0["id"] as? String) == (value["id"] as? String) }, value)
                }
            }
            guard var fields = old as? [String: Any], let updates = new as? [String: Any] else { return new }
            for (key, value) in updates { fields[key] = merge(fields[key], value) }
            return fields
        }
        let old = try original.map { try JSONSerialization.jsonObject(with: $0) }
        return try JSONSerialization.data(withJSONObject: merge(old, current), options: [.sortedKeys])
    }
    public subscript(_ slot: Int) -> Profile? { slots[String(slot)] }
    public func name(_ slot: Int) -> String { self[slot]?.name ?? "Profile \(slot + 1)" }
    public mutating func save(_ slot: Int, preset: OnScreenLayout, layout: ControlLayout) {
        save(slot, outer: Variant(preset: preset, layout: layout), inner: Variant(preset: preset, layout: layout.sideReachLayout()))
    }
    public mutating func save(_ slot: Int, outer: Variant, inner: Variant) {
        guard (0..<Self.count).contains(slot), outer.preset != .off, inner.preset != .off else { return }
        slots[String(slot)] = Profile(name: name(slot), outer: outer, inner: inner)
    }
    public mutating func rename(_ slot: Int, to name: String) {
        guard var value = self[slot] else { return }
        let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
        guard !title.isEmpty else { return }
        value.name = title
        slots[String(slot)] = value
    }
}
