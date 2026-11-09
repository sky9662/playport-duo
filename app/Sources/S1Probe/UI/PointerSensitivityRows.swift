// SPDX-License-Identifier: GPL-3.0-or-later
import PlayportKit
import SwiftUI

struct PointerSensitivityRows: View {
    var gameID: String? = nil
    @ObservedObject private var store = ControlsStore.shared

    var body: some View {
        row(trackpad: true)
        row(trackpad: false)
    }

    private func row(trackpad: Bool) -> some View {
        let key = trackpad ? PointerSensitivity.trackpadKey : PointerSensitivity.mouseKey
        let title = trackpad ? "Touch trackpad sensitivity" : "Mouse sensitivity"
        let defaults = trackpad ? store.defaults.trackpadSensitivity : store.defaults.mouseSensitivity
        let game = gameID.map { store.game($0) }
        let own = trackpad ? game?.trackpadSensitivity : game?.mouseSensitivity
        let value = PointerSensitivity.kept(own) ?? defaults
        return PadRow(id: (gameID == nil ? "set:" : "opt:") + key, title: title,
                      subtitle: trackpad ? "Relative touch trackpad motion" : "Mouse and touch look; controller and gyro are separate",
                      value: PointerSensitivity.label(value), accessory: .chevron,
                      changed: gameID == nil ? defaults != 1 : own != nil, hint: "Change",
                      reset: { set(nil, trackpad: trackpad) }) {
            let first = PadOption(id: "", label: "Default", detail: gameID == nil ? "100%" : PointerSensitivity.label(defaults) + ", from Settings")
            PadModal.shared.picker(title: title, context: gameID == nil ? "Settings · Controls" : "Game · Controls",
                                   note: "Applies immediately. Absolute tap locations and scrolling keep their positions and speed.",
                                   options: [first] + PointerSensitivity.steps.map { PadOption(id: String($0), label: PointerSensitivity.label($0)) },
                                   selected: (gameID == nil ? (defaults == 1 ? nil : defaults) : own).map { String($0) } ?? "") {
                set(Double($0), trackpad: trackpad)
            }
        }
    }

    private func set(_ value: Double?, trackpad: Bool) {
        if let gameID {
            var game = store.game(gameID)
            if trackpad { game.trackpadSensitivity = value } else { game.mouseSensitivity = value }
            store.setGame(gameID, game)
        } else {
            let key = trackpad ? PointerSensitivity.trackpadKey : PointerSensitivity.mouseKey
            if let value { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }
}
