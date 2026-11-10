// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "EndpointKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "EndpointKit", targets: ["EndpointKit"])],
    targets: [
        .target(name: "EndpointKit"),
        .testTarget(name: "EndpointKitTests", dependencies: ["EndpointKit"]),
    ]
)
