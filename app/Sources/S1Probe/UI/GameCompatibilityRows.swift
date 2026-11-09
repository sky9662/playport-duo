// SPDX-License-Identifier: GPL-3.0-or-later
import PlayportKit
import SwiftUI

struct GameCompatibilityRows: View {
    var gameID: String? = nil
    @ObservedObject private var store = LaunchSettingsStore.shared

    var body: some View {
        row("cursor", "Game cursor", "Show the cursor when the game requests it", \.cursor, defaultOn: true)
        row("sharedImage", "DOOM memory compatibility", "Fixes a memory mapping issue; change before starting", \.sharedImage, defaultOn: true)
        row("openGL41", "OpenGL 4.1 compatibility", "Turing compatibility profile; change before starting", \.openGL41, defaultOn: nil)
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
