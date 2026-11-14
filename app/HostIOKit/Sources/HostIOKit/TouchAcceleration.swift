// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// A bounded speed curve in UIKit points/second, before sensitivity is applied.
/// Every sample is forwarded immediately; no startup gate, prediction or inertia.
public enum TouchAcceleration {
    public static func gain(dx: Double, dy: Double, elapsed: Double) -> Double {
        guard dx.isFinite, dy.isFinite, elapsed.isFinite, elapsed > 0 else { return 1 }
        let speed = hypot(dx, dy) / max(elapsed, 0.001)
        let u = min(1, max(0, (speed - 60) / 540))
        return 0.5 + u * u * (3 - 2 * u)
    }
}
