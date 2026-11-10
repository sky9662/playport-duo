// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Select a port only from an advert resolving to this device, never another
/// phone on the LAN. Multiple distinct local ports are ambiguous: keep the
/// historical fallback rather than guessing which service to authenticate to.
public enum RemotePairingEndpoint {
    public static let fallback: UInt16 = 49152

    public struct Advertisement: Sendable {
        public let port: Int
        public let addresses: Set<String>
        public init(port: Int, addresses: Set<String>) {
            self.port = port
            self.addresses = addresses
        }
    }

    public static func select(_ adverts: [Advertisement], localAddresses: Set<String>) -> UInt16? {
        let ports = Set(adverts.compactMap { advert -> UInt16? in
            guard !advert.addresses.isDisjoint(with: localAddresses),
                  let port = UInt16(exactly: advert.port), port > 0 else { return nil }
            return port
        })
        return ports.count == 1 ? ports.first : nil
    }

    #if canImport(Darwin)
    /// Call on a worker thread. Bonjour callbacks use that thread's run loop;
    /// discovery is bounded and never blocks the UI or scans network ports.
    public static func discover() -> UInt16? {
        precondition(!Thread.isMainThread)
        let discovery = Discovery()
        return discovery.run()
    }
    #endif
}

#if canImport(Darwin)
private final class Discovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var adverts: [RemotePairingEndpoint.Advertisement] = []

    func run() -> UInt16? {
        browser.delegate = self
        browser.schedule(in: .current, forMode: .default)
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.05)))
        }
        browser.stop()
        browser.remove(from: .current, forMode: .default)
        for service in services {
            service.stop()
            service.remove(from: .current, forMode: .default)
            service.delegate = nil
        }
        browser.delegate = nil
        return RemotePairingEndpoint.select(adverts, localAddresses: Self.localAddresses())
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.schedule(in: .current, forMode: .default)
        service.resolve(withTimeout: 2)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let addresses = Set((sender.addresses ?? []).compactMap { data -> String? in
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress, raw.count >= MemoryLayout<sockaddr>.size else { return nil }
                let address = base.assumingMemoryBound(to: sockaddr.self)
                guard Int(address.pointee.sa_len) <= raw.count else { return nil }
                return Self.numericAddress(address)
            }
        })
        adverts.append(.init(port: sender.port, addresses: addresses))
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        guard address.pointee.sa_family == AF_INET || address.pointee.sa_family == AF_INET6 else { return nil }
        let expected = address.pointee.sa_family == AF_INET ? MemoryLayout<sockaddr_in>.size : MemoryLayout<sockaddr_in6>.size
        guard Int(address.pointee.sa_len) >= expected else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
        return String(cString: host).split(separator: "%", maxSplits: 1).first.map(String.init)
    }

    private static func localAddresses() -> Set<String> {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        return Set(sequence(first: first, next: { $0.pointee.ifa_next }).compactMap { item in
            guard item.pointee.ifa_flags & UInt32(IFF_UP) != 0, let address = item.pointee.ifa_addr else { return nil }
            return numericAddress(UnsafePointer(address))
        })
    }
}
#endif
