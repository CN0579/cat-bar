import Foundation

@MainActor
final class ConfigDirectoryManager {
    private let supportedConfigExtensions = Set(["yaml", "yml"])
    private let fm = FileManager.default
    private let workingDirectoryManager: WorkingDirectoryManager

    private(set) var configDirectory: URL?
    private(set) var availableConfigs: [URL] = []
    private(set) var selectedConfig: URL?

    init(workingDirectoryManager: WorkingDirectoryManager = WorkingDirectoryManager()) {
        self.workingDirectoryManager = workingDirectoryManager
    }

    func chooseConfigDirectory() -> URL? {
        do {
            try self.workingDirectoryManager.bootstrapDirectories()
            let target = try workingDirectoryManager.normalizeAndValidateWithinRoot(
                self.workingDirectoryManager.configDirectoryURL,
                mustBeDirectory: true)
            self.configDirectory = target
            self.reloadConfigs()
            return target
        } catch {
            return nil
        }
    }

    func setConfigDirectory(_ url: URL) {
        guard let safeURL = try? workingDirectoryManager.normalizeAndValidateWithinRoot(url, mustBeDirectory: true),
              safeURL == workingDirectoryManager.configDirectoryURL.standardizedFileURL.resolvingSymlinksInPath()
        else {
            return
        }
        self.configDirectory = safeURL
        self.reloadConfigs()
    }

    func selectConfig(_ url: URL) {
        guard let configDirectory else { return }
        let candidate = url.standardizedFileURL
        guard candidate.deletingLastPathComponent() == configDirectory,
              self.supportedConfigExtensions.contains(candidate.pathExtension.lowercased()),
              self.isSupportedConfigFile(at: candidate)
        else {
            return
        }
        self.selectedConfig = candidate
    }

    @discardableResult
    func reloadConfigs() -> [URL] {
        guard let configDirectory else {
            self.availableConfigs = []
            selectedConfig = nil
            return []
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        let children = (try? self.fm.contentsOfDirectory(
            at: configDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles])) ?? []
        var files: [URL] = []
        for fileURL in children {
            guard self.supportedConfigExtensions.contains(fileURL.pathExtension.lowercased()),
                  self.isSupportedConfigFile(at: fileURL)
            else {
                continue
            }
            files.append(fileURL)
        }

        files.sort { $0.lastPathComponent < $1.lastPathComponent }
        self.availableConfigs = files

        if let selectedConfig, files.contains(selectedConfig) {
            return files
        }
        selectedConfig = files.first
        return files
    }

    private func isSupportedConfigFile(at url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        if values.isRegularFile == true {
            return true
        }

        guard values.isSymbolicLink == true else { return false }
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        return (try? resolvedURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
