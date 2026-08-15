import Foundation
import Network
import Observation

/// Watches network reachability so tiles that can only play with a connection
/// (YouTube, Apple Music) can be hidden from the child while offline.
@Observable
@MainActor
final class ConnectivityMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.pvd.kidtopia.connectivity")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
