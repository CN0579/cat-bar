import Foundation

struct RemoteMachine: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var secret: String?
    var useHTTPS: Bool
    var webPanelEnabled: Bool?

    var controllerAddress: String {
        if self.useHTTPS {
            return "https://\(self.host):\(self.port)"
        }
        return "\(self.host):\(self.port)"
    }

    var displayAddress: String {
        "\(self.host):\(self.port)"
    }

    var webPanelURL: URL? {
        guard self.webPanelEnabled == true else { return nil }
        var components = URLComponents(string: self.controllerAddress.appending("/ui/"))
        var queryItems = [
            URLQueryItem(name: "host", value: self.host),
            URLQueryItem(name: "hostname", value: self.host),
            URLQueryItem(name: "port", value: "\(self.port)")
        ]
        if let secret = self.secret, !secret.isEmpty {
            queryItems.append(URLQueryItem(name: "secret", value: secret))
        }
        components?.queryItems = queryItems
        let urlString = components?.url?.absoluteString.appending("#/proxies") ?? ""
        return URL(string: urlString)
    }

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 9090,
        secret: String? = nil,
        useHTTPS: Bool = false,
        webPanelEnabled: Bool? = nil)
    {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.secret = secret
        self.useHTTPS = useHTTPS
        self.webPanelEnabled = webPanelEnabled
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
