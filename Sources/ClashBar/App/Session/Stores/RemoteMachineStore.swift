import Foundation

enum MachineConnectionStatus: Equatable {
    case unknown
    case checking
    case connected(version: String)
    case failed(reason: String)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    var shortLabel: String {
        switch self {
        case .unknown:
            "?"
        case .checking:
            "…"
        case let .connected(version):
            "✓ \(version)"
        case let .failed(reason):
            "✗ \(reason)"
        }
    }
}

@MainActor
final class RemoteMachineStore: ObservableObject {
    private struct ConnectivityRequest {
        let token: UUID
        let task: Task<MachineConnectionStatus, Never>
    }

    private static let storageKey = "catbar.remote.machines"
    private static let activeTargetKey = "catbar.remote.active_target_id"

    private let defaults: UserDefaults

    @Published var machines: [RemoteMachine] = []
    @Published var activeTargetID: UUID?
    @Published var machineStatuses: [UUID: MachineConnectionStatus] = [:]
    @Published private(set) var refreshingMachineIDs: Set<UUID> = []

    private var connectivityTimer: Task<Void, Never>?
    private var connectivityRequests: [UUID: ConnectivityRequest] = [:]

    var activeTarget: MachineTarget {
        guard let id = self.activeTargetID,
              let machine = self.machines.first(where: { $0.id == id })
        else {
            return .local
        }
        return .remote(machine)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.machines = Self.loadMachines(from: defaults)
        self.activeTargetID = Self.loadActiveTargetID(from: defaults)
    }

    func addMachine(_ machine: RemoteMachine) {
        self.machines.append(machine)
        self.machineStatuses[machine.id] = .unknown
        self.persist()
    }

    func updateMachine(_ machine: RemoteMachine) {
        guard let index = self.machines.firstIndex(where: { $0.id == machine.id }) else { return }
        self.machines[index] = machine
        self.resetConnectivityState(for: machine.id)
        self.persist()
    }

    func removeMachine(id: UUID) {
        self.cancelConnectivityRequest(for: id)
        self.machines.removeAll { $0.id == id }
        self.machineStatuses.removeValue(forKey: id)
        if self.activeTargetID == id {
            self.activeTargetID = nil
            self.persistActiveTarget()
        }
        self.persist()
    }

    func selectTarget(_ target: MachineTarget) {
        switch target {
        case .local:
            self.activeTargetID = nil
        case let .remote(machine):
            self.activeTargetID = machine.id
        }
        self.persistActiveTarget()
    }

    func resetActiveTarget() {
        self.activeTargetID = nil
        self.persistActiveTarget()
    }

    func statusFor(_ id: UUID) -> MachineConnectionStatus {
        self.machineStatuses[id] ?? .unknown
    }

    func isRefreshing(_ id: UUID) -> Bool {
        self.refreshingMachineIDs.contains(id)
    }

    func checkAllConnectivity() {
        for machine in self.machines {
            self.checkConnectivity(for: machine)
        }
    }

    func checkConnectivity(for machine: RemoteMachine) {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.refreshConnectivity(for: machine)
        }
    }

    @discardableResult
    func refreshConnectivity(for machine: RemoteMachine) async -> MachineConnectionStatus {
        if let existingRequest = self.connectivityRequests[machine.id] {
            return await existingRequest.task.value
        }

        if self.shouldShowCheckingState(for: machine.id) {
            self.machineStatuses[machine.id] = .checking
        }

        self.refreshingMachineIDs.insert(machine.id)

        let token = UUID()
        let task = Task<MachineConnectionStatus, Never> {
            await Self.probe(machine: machine)
        }
        self.connectivityRequests[machine.id] = ConnectivityRequest(token: token, task: task)

        let status = await task.value

        guard self.connectivityRequests[machine.id]?.token == token else {
            return status
        }

        self.connectivityRequests[machine.id] = nil
        self.refreshingMachineIDs.remove(machine.id)
        self.machineStatuses[machine.id] = status
        return status
    }

    func startPeriodicConnectivityChecks() {
        self.stopPeriodicConnectivityChecks()
        self.checkAllConnectivity()
        self.connectivityTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                self?.checkAllConnectivity()
            }
        }
    }

    func stopPeriodicConnectivityChecks() {
        self.connectivityTimer?.cancel()
        self.connectivityTimer = nil
    }

    private func shouldShowCheckingState(for id: UUID) -> Bool {
        guard let currentStatus = self.machineStatuses[id] else { return true }
        if case .unknown = currentStatus {
            return true
        }
        return false
    }

    private func resetConnectivityState(for id: UUID) {
        self.cancelConnectivityRequest(for: id)
        self.machineStatuses[id] = .unknown
    }

    private func cancelConnectivityRequest(for id: UUID) {
        self.connectivityRequests[id]?.task.cancel()
        self.connectivityRequests[id] = nil
        self.refreshingMachineIDs.remove(id)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(self.machines) else { return }
        self.defaults.set(data, forKey: Self.storageKey)
    }

    private func persistActiveTarget() {
        if let id = self.activeTargetID {
            self.defaults.set(id.uuidString, forKey: Self.activeTargetKey)
        } else {
            self.defaults.removeObject(forKey: Self.activeTargetKey)
        }
    }

    private static func loadMachines(from defaults: UserDefaults) -> [RemoteMachine] {
        guard let data = defaults.data(forKey: storageKey),
              let machines = try? JSONDecoder().decode([RemoteMachine].self, from: data)
        else {
            return []
        }
        return machines
    }

    private static func loadActiveTargetID(from defaults: UserDefaults) -> UUID? {
        guard let string = defaults.string(forKey: activeTargetKey) else { return nil }
        return UUID(uuidString: string)
    }

    private static func probe(machine: RemoteMachine) async -> MachineConnectionStatus {
        let timeoutInterval: TimeInterval = 1
        let address = machine.controllerAddress
        let base = address.contains("://") ? address : "http://\(address)"
        guard let url = URL(string: "\(base)/version") else {
            return .failed(reason: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        if let secret = machine.secret, !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeoutInterval
            configuration.timeoutIntervalForResource = timeoutInterval
            let session = URLSession(configuration: configuration)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failed(reason: "No HTTP response")
            }
            if httpResponse.statusCode == 401 {
                return .failed(reason: "Auth failed (401)")
            }
            guard httpResponse.statusCode == 200 else {
                return .failed(reason: "HTTP \(httpResponse.statusCode)")
            }
            if let json = try? JSONDecoder().decode([String: String].self, from: data),
               let version = json["version"]
            {
                return .connected(version: version)
            }
            return .connected(version: "OK")
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .failed(reason: "Timeout")
            case .cannotConnectToHost:
                return .failed(reason: "Connection refused")
            case .networkConnectionLost:
                return .failed(reason: "Connection lost")
            default:
                return .failed(reason: error.localizedDescription)
            }
        } catch {
            return .failed(reason: error.localizedDescription)
        }
    }
}
