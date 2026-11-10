// SPDX-License-Identifier: GPL-3.0-or-later
import PlayportKit
import SwiftUI

struct GameCompatibilityRows: View {
    var gameID: String? = nil
    var appID: UInt32? = nil
    @ObservedObject private var store = LaunchSettingsStore.shared

    var body: some View {
        row("cursor", "Game cursor", "Show the cursor when the game requests it", \.cursor, defaultOn: true)
        cursorSize
        row("cursorSmooth", "Smooth cursor scaling", "Smooths enlarged game cursors; Off keeps original pixel edges", \.cursorSmooth, defaultOn: true)
        row("sharedImage", "DOOM memory compatibility", "Fixes a memory mapping issue; change before starting", \.sharedImage, defaultOn: true)
        row("openGL41", "OpenGL 4.1 compatibility",
            profileGL41 == true ? "Game profile enables OpenGL 4.1 / GLSL 410 overrides. Restart the game after changing."
                : "Use OpenGL 4.1 / GLSL 410 version overrides for shader compatibility. Restart the game after changing.",
            \.openGL41, defaultOn: profileGL41)
    }

    private var profileGL41: Bool? {
        guard let gameID else { return nil }
        let settings = store.compat(for: gameID)?.settings
        return settings?.compatibility.openGL41
            ?? GameCompatibility.profileUsesOpenGL41(LaunchSettings.releaseRuntime(compat: settings))
    }

    private var cursorSize: some View {
        let binding = gameID.map { store.binding(for: $0) } ?? $store.global
        let own = GameCompatibility.keptCursorScale(binding.wrappedValue.compatibility.cursorScale)
        let inherited = (gameID == nil ? nil : GameCompatibility.keptCursorScale(store.global.compatibility.cursorScale))
            ?? GameCompatibility.defaultCursorScale(appID: appID)
        return PadRow(id: (gameID == nil ? "set:" : "opt:") + "cursorSize", title: "Cursor size",
                      subtitle: "Enlarge the game cursor; its click point stays aligned",
                      value: (own == nil ? "Default · " : "") + PointerSensitivity.label(own ?? inherited),
                      accessory: .chevron, changed: own != nil, hint: "Change",
                      reset: { binding.wrappedValue.compatibility.cursorScale = nil }) {
            PadModal.shared.picker(title: "Cursor size", context: "Game cursor", note: "Applies immediately. Turing Complete defaults to 200%.",
                options: [PadOption(id: "", label: "Default", detail: PointerSensitivity.label(inherited))]
                    + [1.0, 1.5, 2, 2.5, 3, 4].map { PadOption(id: String($0), label: PointerSensitivity.label($0)) },
                selected: own.map { String($0) } ?? "") {
                    binding.wrappedValue.compatibility.cursorScale = GameCompatibility.keptCursorScale(Double($0))
                }
        }
    }

    private func row(_ id: String, _ title: String, _ note: String, _ key: WritableKeyPath<GameCompatibility, Bool?>,
                     defaultOn: Bool?) -> some View {
        let binding = gameID.map { store.binding(for: $0) } ?? $store.global
        let own = binding.wrappedValue.compatibility[keyPath: key]
        let inherited = gameID == nil ? defaultOn : store.global.compatibility[keyPath: key] ?? defaultOn
        let value = own.map { $0 ? "On" : "Off" } ?? (inherited.map { "Default · " + ($0 ? "On" : "Off") } ?? "Default · Game profile")
        return PadRow(id: (gameID == nil ? "set:" : "opt:") + id, title: title, subtitle: note,
                      value: value, accessory: .chevron, changed: own != nil, hint: "Change",
                      reset: { binding.wrappedValue.compatibility[keyPath: key] = nil }) {
            PadModal.shared.picker(title: title, context: gameID == nil ? "Settings · Graphics" : "Game · Compatibility",
                                   note: note,
                                   options: [PadOption(id: "", label: "Default", detail: gameID == nil ? "Built-in behavior" : "Follow Settings and game profile"),
                                             PadOption(id: "on", label: "On"), PadOption(id: "off", label: "Off")],
                                   selected: own.map { $0 ? "on" : "off" } ?? "") {
                binding.wrappedValue.compatibility[keyPath: key] = $0.isEmpty ? nil : $0 == "on"
            }
        }
    }
}
