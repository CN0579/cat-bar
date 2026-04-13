import XCTest
@testable import CatBar

@MainActor
final class ConfigDirectoryManagerTests: XCTestCase {
    func testChooseConfigDirectoryIncludesSymlinkedYamlConfig() throws {
        let temporaryDirectory = try self.makeTemporaryDirectory()
        let manager = self.makeManager(homeDirectory: temporaryDirectory)
        let configDirectory = try self.requireConfigDirectory(for: manager)
        let externalConfigURL = temporaryDirectory
            .appendingPathComponent("external", isDirectory: true)
            .appendingPathComponent("profile.yaml", isDirectory: false)
        try FileManager.default.createDirectory(
            at: externalConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("port: 7890".utf8).write(to: externalConfigURL)

        let symlinkURL = configDirectory.appendingPathComponent("linked.yaml", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: externalConfigURL)

        let files = manager.reloadConfigs()

        XCTAssertEqual(files.map(\.standardizedFileURL), [symlinkURL.standardizedFileURL])
        XCTAssertEqual(manager.selectedConfig?.standardizedFileURL, symlinkURL.standardizedFileURL)
    }

    func testSelectConfigKeepsSymlinkPathWhenTargetIsOutsideManagedDirectory() throws {
        let temporaryDirectory = try self.makeTemporaryDirectory()
        let manager = self.makeManager(homeDirectory: temporaryDirectory)
        let configDirectory = try self.requireConfigDirectory(for: manager)
        let externalConfigURL = temporaryDirectory
            .appendingPathComponent("outside.yaml", isDirectory: false)
        try Data("mode: rule".utf8).write(to: externalConfigURL)

        let symlinkURL = configDirectory.appendingPathComponent("outside-link.yaml", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: externalConfigURL)

        _ = manager.reloadConfigs()
        manager.selectConfig(symlinkURL)

        XCTAssertEqual(manager.selectedConfig?.standardizedFileURL, symlinkURL.standardizedFileURL)
    }

    func testReloadConfigsExcludesDirectorySymlinks() throws {
        let temporaryDirectory = try self.makeTemporaryDirectory()
        let manager = self.makeManager(homeDirectory: temporaryDirectory)
        let configDirectory = try self.requireConfigDirectory(for: manager)
        let externalDirectoryURL = temporaryDirectory.appendingPathComponent("external-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: externalDirectoryURL, withIntermediateDirectories: true)

        let symlinkURL = configDirectory.appendingPathComponent("folder.yaml", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: externalDirectoryURL)

        XCTAssertTrue(manager.reloadConfigs().isEmpty)
        XCTAssertNil(manager.selectedConfig)
    }

    private func makeManager(homeDirectory: URL) -> ConfigDirectoryManager {
        ConfigDirectoryManager(
            workingDirectoryManager: WorkingDirectoryManager(homeDirectory: homeDirectory))
    }

    private func requireConfigDirectory(for manager: ConfigDirectoryManager) throws -> URL {
        guard let configDirectory = manager.chooseConfigDirectory() else {
            throw XCTSkip("failed to bootstrap config directory")
        }
        return configDirectory
    }

    private func makeTemporaryDirectory() throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        self.addTeardownBlock {
            if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
                try FileManager.default.removeItem(at: temporaryDirectory)
            }
        }
        return temporaryDirectory
    }
}
