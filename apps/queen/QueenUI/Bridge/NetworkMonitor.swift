import Foundation
import Network
import SwiftUI

/// Monitors device network connectivity via NWPathMonitor.
/// Publishes `isConnected` and `connectionType` for instant WiFi/cellular detection.
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var wasDisconnected: Bool = false  // true after reconnection (for toast)

    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case wired = "Ethernet"
        case unknown = "Unknown"
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "queen.network.monitor")
    private var previouslyConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let connected = path.status == .satisfied
                let type: ConnectionType = {
                    if path.usesInterfaceType(.wifi) { return .wifi }
                    if path.usesInterfaceType(.cellular) { return .cellular }
                    if path.usesInterfaceType(.wiredEthernet) { return .wired }
                    return .unknown
                }()

                // Detect reconnection
                if connected && !self.previouslyConnected {
                    self.wasDisconnected = true
                    // Auto-dismiss reconnection flag after 3s
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        self.wasDisconnected = false
                    }
                }

                self.previouslyConnected = connected
                self.isConnected = connected
                self.connectionType = type
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
