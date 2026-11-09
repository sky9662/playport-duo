// SPDX-License-Identifier: GPL-3.0-or-later
#if canImport(UIKit)
import UIKit

/// The app's visible scene, including folding and window resizing. No device dimensions.
@MainActor
enum SceneDisplay {
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
    static var usesSideControls: Bool { window?.traitCollection.horizontalSizeClass == .regular }
}
#endif
