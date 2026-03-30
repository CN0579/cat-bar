import Foundation

struct DefaultMaintenanceRepository: MaintenanceRepository, Sendable {
    private let transport: any MihomoAPITransporting

    init(transport: any MihomoAPITransporting) {
        self.transport = transport
    }

    func upgradeCore() async throws -> CoreUpgradeResponse {
        try await self.transport.request(.upgradeCore)
    }

    func flushFakeIPCache() async throws {
        try await self.transport.requestNoResponse(.flushFakeIPCache)
    }

    func flushDNSCache() async throws {
        try await self.transport.requestNoResponse(.flushDNSCache)
    }

    func restartCore() async throws {
        try await self.transport.requestNoResponse(.restartCore)
    }

    func updateGeoData() async throws {
        try await self.transport.requestNoResponse(.updateGeoData)
    }

    func fetchVersion() async throws -> VersionInfo {
        try await self.transport.request(.version)
    }
}
