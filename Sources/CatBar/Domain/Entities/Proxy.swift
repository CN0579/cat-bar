import Foundation

struct ProxyGroupsResponse: Decodable, Equatable {
    let proxies: [String: ProxyGroup]
}

struct ProxyGroup: Decodable, Equatable {
    let id: String?
    let name: String
    let type: String?
    let now: String?
    let all: [String]
    let providerName: String?
    let alive: Bool?
    let testUrl: String?
    let timeout: Int?
    let icon: String?
    let hidden: Bool?
    let latestDelay: Int?

    init(
        id: String? = nil,
        name: String,
        type: String? = nil,
        now: String? = nil,
        all: [String],
        providerName: String? = nil,
        alive: Bool? = nil,
        testUrl: String? = nil,
        timeout: Int? = nil,
        icon: String? = nil,
        hidden: Bool? = nil,
        latestDelay: Int? = nil)
    {
        self.id = id?.trimmedNonEmpty
        self.name = name
        self.type = type
        self.now = now
        self.all = all
        self.providerName = providerName?.trimmedNonEmpty
        self.alive = alive
        self.testUrl = testUrl.trimmedNonEmpty
        self.timeout = timeout.positiveOrNil
        self.icon = icon.trimmedNonEmpty
        self.hidden = hidden
        self.latestDelay = latestDelay
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case now
        case all
        case providerName = "provider-name"
        case alive
        case testUrl
        case timeout
        case icon
        case hidden
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id).trimmedNonEmpty
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.now = try container.decodeIfPresent(String.self, forKey: .now)
        self.all = try container.decodeIfPresent([String].self, forKey: .all) ?? []
        self.providerName = try container.decodeIfPresent(String.self, forKey: .providerName).trimmedNonEmpty
        self.alive = try container.decodeIfPresent(Bool.self, forKey: .alive)
        self.testUrl = try container.decodeIfPresent(String.self, forKey: .testUrl).trimmedNonEmpty
        self.timeout = container.decodeFlexibleInt(forKey: .timeout).positiveOrNil
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon).trimmedNonEmpty
        self.hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden)
        self.latestDelay = container.decodeLatestDelay(forKey: .history)
    }
}

struct ConfigSnapshot: Codable, Equatable {
    struct TunConfig: Codable, Equatable {
        let enable: Bool?
        let stack: String?

        private enum CodingKeys: String, CodingKey {
            case enable
            case stack
        }

        init(enable: Bool?, stack: String?) {
            self.enable = enable
            self.stack = stack
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.enable = container.decodeFlexibleBool(forKey: .enable)
            self.stack = container.decodeFlexibleString(forKey: .stack)
        }
    }

    let allowLan: Bool?
    let mode: String?
    let logLevel: String?
    let ipv6: Bool?
    let tcpConcurrent: Bool?
    let port: Int?
    let socksPort: Int?
    let redirPort: Int?
    let tproxyPort: Int?
    let mixedPort: Int?
    let tun: TunConfig?
    let externalController: String?
    let externalControllerTLS: String?
    let externalUI: String?
    let externalUIName: String?
    let secret: String?

    var tunEnabled: Bool? {
        self.tun?.enable
    }

    init(
        allowLan: Bool?,
        mode: String?,
        logLevel: String?,
        ipv6: Bool?,
        tcpConcurrent: Bool?,
        port: Int?,
        socksPort: Int?,
        redirPort: Int?,
        tproxyPort: Int?,
        mixedPort: Int?,
        tun: TunConfig?,
        externalController: String?,
        externalControllerTLS: String? = nil,
        externalUI: String? = nil,
        externalUIName: String? = nil,
        secret: String? = nil)
    {
        self.allowLan = allowLan
        self.mode = mode
        self.logLevel = logLevel
        self.ipv6 = ipv6
        self.tcpConcurrent = tcpConcurrent
        self.port = port
        self.socksPort = socksPort
        self.redirPort = redirPort
        self.tproxyPort = tproxyPort
        self.mixedPort = mixedPort
        self.tun = tun
        self.externalController = externalController
        self.externalControllerTLS = externalControllerTLS
        self.externalUI = externalUI
        self.externalUIName = externalUIName
        self.secret = secret
    }

    private enum CodingKeys: String, CodingKey {
        case allowLan = "allow-lan"
        case mode
        case logLevel = "log-level"
        case ipv6
        case tcpConcurrent = "tcp-concurrent"
        case port
        case socksPort = "socks-port"
        case redirPort = "redir-port"
        case tproxyPort = "tproxy-port"
        case mixedPort = "mixed-port"
        case tun
        case externalController = "external-controller"
        case externalControllerTLS = "external-controller-tls"
        case externalUI = "external-ui"
        case externalUIName = "external-ui-name"
        case secret
    }
}
