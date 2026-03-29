import Foundation

@MainActor
final class ConnectionsStore: ObservableObject {
    @Published private(set) var connections: [ConnectionSummary] = []
    @Published var connectionsCount: Int = 0
    /// Increments only when the connections array payload changes (cheap `onChange` signal).
    @Published private(set) var connectionsRevision: UInt64 = 0

    func replaceConnections(_ next: [ConnectionSummary]) {
        guard self.connections != next else { return }
        self.connections = next
        self.connectionsRevision &+= 1
    }

    func clearConnectionsList() {
        guard !self.connections.isEmpty else { return }
        self.connections.removeAll(keepingCapacity: false)
        self.connectionsRevision &+= 1
    }
}
