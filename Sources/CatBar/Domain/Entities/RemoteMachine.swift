import Foundation

struct RemoteMachine: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var secret: String?
    var useHTTPS: Bool
    var showsWebDashboardButton: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case port
        case secret
        case useHTTPS
        case showsWebDashboardButton
    }

    var controllerAddress: String {
        if self.useHTTPS {
            return "https://\(self.host):\(self.port)"
        }
        return "\(self.host):\(self.port)"
    }

    var displayAddress: String {
        return "\(self.host):\(self.port)"
    }

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 9090,
        secret: String? = nil,
        useHTTPS: Bool = false,
        showsWebDashboardButton: Bool = false)
    {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.secret = secret
        self.useHTTPS = useHTTPS
        self.showsWebDashboardButton = showsWebDashboardButton
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.host = try container.decode(String.self, forKey: .host)
        self.port = try container.decode(Int.self, forKey: .port)
        self.secret = try container.decodeIfPresent(String.self, forKey: .secret)
        self.useHTTPS = try container.decode(Bool.self, forKey: .useHTTPS)
        self.showsWebDashboardButton =
            try container.decodeIfPresent(Bool.self, forKey: .showsWebDashboardButton) ?? false
    }
}

enum MachineTarget: Equatable, Hashable {
    case local
    case remote(RemoteMachine)

    var isLocal: Bool {
        if case .local = self {
            return true
        }
        return false
    }

    var remoteMachine: RemoteMachine? {
        if case let .remote(machine) = self {
            return machine
        }
        return nil
    }
}
