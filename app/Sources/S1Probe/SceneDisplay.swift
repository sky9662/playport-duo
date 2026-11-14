// SPDX-License-Identifier: GPL-3.0-or-later
#if canImport(UIKit)
import UIKit
import Darwin
import PlayportKit

/// The app's visible scene, including folding and window resizing. No device dimensions.
@MainActor
enum SceneDisplay {
    /// Exact hardware allowlist; an unknown device always keeps the standard UI.
    static let uiProfile: DeviceUIProfile = {
        #if targetEnvironment(simulator)
        return DeviceUIProfile(machineIdentifier: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "")
        #else
        var identity = utsname()
        guard uname(&identity) == 0 else { return .standard }
        let machine = withUnsafeBytes(of: &identity.machine) {
            String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
        }
        return DeviceUIProfile(machineIdentifier: machine)
        #endif
    }()
    static var usesDuoLayout: Bool { uiProfile == .duo }

    static var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        return active.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? active.flatMap(\.windows).first(where: { !$0.isHidden })
    }
    static var pixelSize: CGSize {
        guard let window, let screen = window.windowScene?.screen else { return .zero }
        return CGSize(width: window.bounds.width * screen.nativeScale,
                      height: window.bounds.height * screen.nativeScale)
    }
    static var maximumRate: Int { window?.windowScene?.screen.maximumFramesPerSecond ?? 60 }
    /// The expanded scene's layout class, rather than a model name or panel pixels.
    static var usesSideControls: Bool {
        uiProfile.expandedControls(isRegular: window?.traitCollection.horizontalSizeClass == .regular)
    }
}
#endif
