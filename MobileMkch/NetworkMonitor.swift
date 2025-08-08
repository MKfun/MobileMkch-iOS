import Foundation
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isConnected: Bool = true
    @Published var forceOffline: Bool = UserDefaults.standard.bool(forKey: "ForceOffline") {
        didSet { UserDefaults.standard.set(forceOffline, forKey: "ForceOffline") }
    }
    var offlineEffective: Bool { forceOffline || !isConnected }
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor.queue")
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}


