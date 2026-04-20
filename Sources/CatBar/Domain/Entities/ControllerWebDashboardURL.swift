import Foundation

struct ControllerWebDashboardURL {
    let controller: String
    let tlsController: String?
    let externalUI: String?
    let externalUIName: String?
    let secret: String?
    let publicHost: String?

    func url() -> URL? {
        guard var components = URLComponents(string: self.normalizedControllerAddress()) else {
            return nil
        }

        let resolvedHost = self.resolvedPublicHost(for: components.host)
        if let resolvedHost {
            components.host = resolvedHost
        }
        components.path = self.dashboardPath()
        components.queryItems = self.queryItems(host: resolvedHost ?? components.host, port: components.port, scheme: components.scheme)
        return components.url
    }

    private func normalizedControllerAddress() -> String {
        let rawController = self.tlsController?.trimmedNonEmpty ?? self.controller
        let hasScheme = rawController.hasPrefix("http://") || rawController.hasPrefix("https://")
        if hasScheme {
            return rawController
        }
        return "\(self.defaultScheme())://\(rawController)"
    }

    private func defaultScheme() -> String {
        guard let components = URLComponents(string: self.controllerWithDefaultScheme()),
              let scheme = components.scheme?.trimmedNonEmpty
        else {
            return "http"
        }
        return scheme
    }

    private func controllerWithDefaultScheme() -> String {
        if self.controller.hasPrefix("http://") || self.controller.hasPrefix("https://") {
            return self.controller
        }
        return "http://\(self.controller)"
    }

    private func resolvedPublicHost(for host: String?) -> String? {
        let fallback = self.publicHost?.trimmedNonEmpty
        guard let host = host?.trimmedNonEmpty else {
            return fallback
        }
        switch host.lowercased() {
        case "0.0.0.0", "::", "0:0:0:0:0:0:0:0":
            return fallback ?? "127.0.0.1"
        default:
            return host
        }
    }

    private func dashboardPath() -> String {
        let base = Self.normalizedPathSegment(self.externalUI) ?? "ui"
        guard let name = Self.normalizedPathSegment(self.externalUIName) else {
            return "/\(base)"
        }
        return "/\(base)/\(name)/"
    }

    private func queryItems(host: String?, port: Int?, scheme: String?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let host = host?.trimmedNonEmpty {
            items.append(URLQueryItem(name: "host", value: host))
            items.append(URLQueryItem(name: "hostname", value: host))
        }
        if let port {
            items.append(URLQueryItem(name: "port", value: String(port)))
        } else if let scheme {
            items.append(URLQueryItem(name: "port", value: scheme == "https" ? "443" : "80"))
        }
        if let secret = self.secret?.trimmedNonEmpty {
            items.append(URLQueryItem(name: "secret", value: secret))
        }
        return items
    }

    private static func normalizedPathSegment(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .trimmedNonEmpty
    }
}
