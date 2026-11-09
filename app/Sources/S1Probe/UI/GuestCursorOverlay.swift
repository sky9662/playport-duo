// SPDX-License-Identifier: GPL-3.0-or-later
#if canImport(UIKit)
import UIKit
import QuartzCore
import HostIO
import PlayportKit

/// Presentation only: Wine owns position, clipping, shape and visibility.
/// A display tick observes drawable-size changes even without a UIKit layout.
@MainActor
final class GuestCursorOverlay: UIView {
    private var clock: CADisplayLink?
    private let pictureMask = CAShapeLayer()
    private var lastPicture = CGRect.null
    private let cursor = Unmanaged<CALayer>.fromOpaque(host_game_cursor_layer()).takeUnretainedValue()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        layer.mask = pictureMask
        layer.addSublayer(cursor)
    }

    required init?(coder: NSCoder) { fatalError("created in code") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        clock?.invalidate()
        clock = nil
        if window != nil {
            // A weak target avoids a view/display-link retain cycle.
            let link = CADisplayLink(target: Tick(self), selector: #selector(Tick.fire))
            link.add(to: .main, forMode: .common)
            clock = link
        } else {
            host_game_cursor_present(0, 0, 0, 0, 0)
        }
    }

    private func refresh() {
        let picture = GameSurfaceView.current?.picture ?? .zero
        if picture != lastPicture {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            pictureMask.path = UIBezierPath(rect: picture).cgPath
            CATransaction.commit()
            lastPicture = picture
        }
        let compatibility = LaunchSettingsStore.shared.compatibility(for: TitleLaunch.shared.titleID)
        let scale = GameCompatibility.keptCursorScale(compatibility.cursorScale)
            ?? GameCompatibility.defaultCursorScale(appID: TitleLaunch.shared.appID)
        let allowed = (compatibility.cursor ?? true)
            && window != nil && HostIO.shared.cursorAllowed && !GuestWindows.shown
            && UIApplication.shared.applicationState == .active
        host_game_cursor_present_scaled(picture.minX, picture.minY, picture.width, picture.height, allowed ? 1 : 0, scale)
    }

    @MainActor private final class Tick: NSObject {
        weak var view: GuestCursorOverlay?
        init(_ view: GuestCursorOverlay) { self.view = view }
        @objc func fire(_ link: CADisplayLink) {
            guard let view else { link.invalidate(); return }
            view.refresh()
        }
    }
}
#endif
