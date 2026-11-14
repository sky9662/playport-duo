// SPDX-License-Identifier: GPL-3.0-or-later
/// Independent multipliers for touch trackpad motion and ordinary relative mouse motion.
/// Absolute placement, scrolling, controller look and gyro keep their own units.
public enum PointerSensitivity {
    public static let trackpadKey = "controls.trackpadSensitivity"
    public static let mouseKey = "controls.mouseSensitivity"
    public static let accelerationKey = "controls.pointerAcceleration"
    public static let steps: [Double] = [0.1, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]
    public static func kept(_ value: Double?) -> Double? {
        value.flatMap { $0.isFinite && (0.1...4).contains($0) ? $0 : nil }
    }
    public static func label(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    public static func step(_ value: Double, by direction: Int, wrapping: Bool = false) -> Double {
        let at = steps.indices.min { abs(steps[$0] - value) < abs(steps[$1] - value) } ?? 4
        let next = at + direction
        if wrapping { return steps[(next % steps.count + steps.count) % steps.count] }
        return steps[min(steps.count - 1, max(0, next))]
    }
}
