// SPDX-License-Identifier: GPL-3.0-or-later
import PlayportKit
import SwiftUI

struct PointerSensitivityRows: View {
    var gameID: String? = nil
    @ObservedObject private var store = ControlsStore.shared

    var body: some View {
        row(trackpad: true)
        row(trackpad: false)
        accelerationRow
    }

    private var accelerationRow: some View {
        let own = gameID.map { store.game($0) }?.pointerAcceleration
        let value = own ?? store.defaults.pointerAcceleration
        return PadRow(id: (gameID == nil ? "set:" : "opt:") + PointerSensitivity.accelerationKey,
                      title: "Touch acceleration", subtitle: "Touch trackpad and touch look: slow is finer, fast travels farther",
                      value: value ? "On" : "Off", accessory: .chevron,
                      changed: gameID == nil ? !value : own != nil, hint: "Change",
                      reset: { setAcceleration(nil) }) {
            PadModal.shared.picker(title: "Touch acceleration", context: gameID == nil ? "Settings · Controls" : "Game · Controls",
                note: "Applies on top of your sensitivity. Off restores constant speed. Does not change physical mouse, scrolling, controller or gyro input.",
                options: [PadOption(id: "", label: "Default", detail: gameID == nil ? "On" : (store.defaults.pointerAcceleration ? "On" : "Off") + ", from Settings"),
                          PadOption(id: "on", label: "On"), PadOption(id: "off", label: "Off")],
                selected: (gameID == nil ? (value ? nil : false) : own).map { $0 ? "on" : "off" } ?? "") {
                    setAcceleration($0.isEmpty ? nil : $0 == "on")
                }
        }
    }

    private func setAcceleration(_ value: Bool?) {
        if let gameID {
            var game = store.game(gameID)
            game.pointerAcceleration = value
            store.setGame(gameID, game)
        } else if let value {
            UserDefaults.standard.set(value, forKey: PointerSensitivity.accelerationKey)
        } else {
            UserDefaults.standard.removeObject(forKey: PointerSensitivity.accelerationKey)
        }
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
