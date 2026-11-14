// SPDX-License-Identifier: GPL-3.0-or-later
/// Hardware-specific presentation. Geometry is used only after the hardware
/// matches: iPads and other iPhones must retain the standard presentation.
public enum DeviceUIProfile: Equatable, Sendable {
    case standard, duo

    public init(machineIdentifier: String) {
        self = machineIdentifier == "iPhone19,4" ? .duo : .standard
    }

    public func expandedControls(isRegular: Bool) -> Bool { self == .duo && isRegular }

    public func libraryColumns(width: Double, spacing: Double = 14) -> Int {
        guard self == .duo else { return 4 }
        return max(1, min(6, Int((max(0, width) + spacing) / (128 + spacing))))
    }
}
