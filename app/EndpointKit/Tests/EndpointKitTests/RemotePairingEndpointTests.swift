// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import EndpointKit

final class RemotePairingEndpointTests: XCTestCase {
    func testUsesOwnChangedPortAndIgnoresOtherPhones() {
        XCTAssertEqual(RemotePairingEndpoint.select([
            .init(port: 54833, addresses: ["192.0.2.2"]),
            .init(port: 49442, addresses: ["192.0.2.1", "2001:db8::1"]),
        ], localAddresses: ["192.0.2.1"]), 49442)
    }

    func testIPv6AndDuplicateAdvertisementsAgree() {
        XCTAssertEqual(RemotePairingEndpoint.select([
            .init(port: 49442, addresses: ["2001:db8::1"]),
            .init(port: 49442, addresses: ["192.0.2.1"]),
        ], localAddresses: ["2001:db8::1", "192.0.2.1"]), 49442)
    }

    func testNoOwnAdvertDoesNotSelectAnotherPhone() {
        XCTAssertNil(RemotePairingEndpoint.select([.init(port: 49442, addresses: ["192.0.2.2"])], localAddresses: ["192.0.2.1"]))
        XCTAssertNil(RemotePairingEndpoint.select([], localAddresses: ["192.0.2.1"]))
    }

    func testAmbiguousOwnPortsDoNotGuess() {
        XCTAssertNil(RemotePairingEndpoint.select([
            .init(port: 49442, addresses: ["192.0.2.1"]),
            .init(port: 54833, addresses: ["192.0.2.1"]),
        ], localAddresses: ["192.0.2.1"]))
    }

    func testInvalidPortsAndMissingLocalAddresses() {
        for port in [-1, 0, 65536] {
            XCTAssertNil(RemotePairingEndpoint.select([.init(port: port, addresses: ["192.0.2.1"])], localAddresses: ["192.0.2.1"]))
        }
        XCTAssertNil(RemotePairingEndpoint.select([.init(port: 49442, addresses: ["192.0.2.1"])], localAddresses: []))
    }
}
