import Foundation

@MainActor
extension AppSession {
    func restorePersistedPresentationSource() {
        self.restoreLocalControllerDisplayFromSelectedConfigIfAvailable()

        switch self.remoteMachineStore.activeTarget {
        case .local:
            self.restoreLocalPresentationSource()
        case let .remote(machine):
            self.restoreRemotePresentationSource(machine)
        }
    }

    func resolveSelectedConfigPath() async -> String? {
        if let selected = configRepository.selectedConfig {
            let selectedPath = self.syncSelectedConfigSelection(selected)
            self.syncConfigDisplayState()
            return selectedPath
        }

        if let selectedName = defaults.string(forKey: selectedConfigKey),
           let selected = configRepository.availableConfigs.first(where: { $0.lastPathComponent == selectedName })
        {
            configRepository.selectConfig(selected)
            let selectedPath = self.syncSelectedConfigSelection(selected)
            self.syncConfigDisplayState()
            return selectedPath
        }

        if let legacySelectedPath = defaults.string(forKey: legacySelectedConfigKey) {
            let legacyName = URL(fileURLWithPath: legacySelectedPath).lastPathComponent
            defaults.set(legacyName, forKey: selectedConfigKey)
            defaults.removeObject(forKey: legacySelectedConfigKey)
            if let selected = configRepository.availableConfigs.first(where: { $0.lastPathComponent == legacyName }) {
                configRepository.selectConfig(selected)
                let selectedPath = self.syncSelectedConfigSelection(selected)
                self.syncConfigDisplayState()
                return selectedPath
            }
        }

        _ = configRepository.reloadConfigs()
        if let selected = configRepository.selectedConfig {
            let selectedPath = self.syncSelectedConfigSelection(selected)
            self.syncConfigDisplayState()
            return selectedPath
        }

        return nil
    }

    func restoreSavedConfigDirectory() {
        configRepository.setConfigDirectory(workingDirectoryManager.configDirectoryURL)
        if let selected = configRepository.selectedConfig {
            _ = self.syncSelectedConfigSelection(selected)
        }
        self.syncConfigDisplayState()
    }

    func restoreLastSuccessfulConfigIfAvailable() {
        guard let lastPath = defaults.string(forKey: lastSuccessfulConfigPathKey), !lastPath.isEmpty else { return }
        let candidate = URL(fileURLWithPath: lastPath)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return }
        guard let matched = configRepository.availableConfigs.first(where: {
            $0.standardizedFileURL.resolvingSymlinksInPath().path == candidate.standardizedFileURL
                .resolvingSymlinksInPath().path
        }) else {
            return
        }
        configRepository.selectConfig(matched)
        _ = self.syncSelectedConfigSelection(matched)
        self.syncConfigDisplayState()
    }

    func syncConfigDisplayState() {
        configDirectoryPath = configRepository.configDirectory?.path ?? "-"
        availableConfigFileNames = configRepository.availableConfigs.map(\.lastPathComponent)
        if selectedConfigName == "-", let first = availableConfigFileNames.first {
            selectedConfigName = first
        }
        self.pruneRemoteConfigSourcesIfNeeded()
    }

    func ensureAPIClient() {
        if let apiClient {
            apiClient.updateCredentials(controller: controller, secret: controllerSecret)
        } else {
            apiClient = MihomoAPIClient(controller: controller, secret: controllerSecret)
        }
    }

    func persistEditableSettingsSnapshot() {
        guard !suppressSettingsPersistence else { return }
        guard !self.isRemoteTarget else { return }
        let snapshot = currentEditableSettingsSnapshot()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: editableSettingsSnapshotKey)
    }

    func loadPersistedEditableSettingsSnapshot() -> EditableSettingsSnapshot? {
        guard let data = defaults.data(forKey: editableSettingsSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(EditableSettingsSnapshot.self, from: data)
    }

    func loadPersistedUILanguage() -> AppLanguage {
        if let raw = defaults.string(forKey: uiLanguageKey),
           let language = AppLanguage(rawValue: raw)
        {
            return language
        }
        defaults.set(AppLanguage.zhHans.rawValue, forKey: uiLanguageKey)
        return .zhHans
    }

    func loadPersistedAppearanceMode() -> AppAppearanceMode {
        if let raw = defaults.string(forKey: appearanceModeKey),
           let mode = AppAppearanceMode(rawValue: raw)
        {
            return mode
        }
        defaults.set(AppAppearanceMode.system.rawValue, forKey: appearanceModeKey)
        return .system
    }

    func loadPersistedRemoteConfigSources() -> [String: String] {
        guard let stored = defaults.dictionary(forKey: remoteConfigSourcesKey) as? [String: String] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (fileName, urlString) in stored {
            guard let normalizedName = normalizedConfigFileName(fileName), normalizedName == fileName else { continue }
            guard let url = URL(string: urlString), isSupportedRemoteConfigURL(url) else { continue }
            result[normalizedName] = url.absoluteString
        }
        return result
    }

    func persistRemoteConfigSources() {
        defaults.set(remoteConfigSources, forKey: remoteConfigSourcesKey)
    }

    func pruneRemoteConfigSourcesIfNeeded() {
        let availableNames = Set(availableConfigFileNames)
        let filtered = remoteConfigSources.filter { availableNames.contains($0.key) }
        guard filtered != remoteConfigSources else { return }
        remoteConfigSources = filtered
        self.persistRemoteConfigSources()
    }

    private func restoreLocalPresentationSource() {
        if let selectedConfigPath = self.configRepository.selectedConfig?.path {
            self.applyExternalControllerFromSelectedConfigFile(configPath: selectedConfigPath)
        } else {
            let fallbackController = "127.0.0.1:9090"
            self.controller = fallbackController
            self.controllerSecret = nil
            self.externalControllerDisplay = fallbackController
            self.localExternalControllerDisplay = fallbackController
            self.controllerUIURL = self.makeControllerUIURL(fallbackController)
            self.ensureAPIClient()
        }

        guard let snapshot = self.loadPersistedEditableSettingsSnapshot() else { return }
        self.applyEditableSettingsSnapshotToUI(snapshot)
        self.lastSyncedEditableSettings = snapshot
        self.preserveLocalSettingsOnNextSync = true
        self.pendingAppLaunchOverlaySettings = snapshot
    }

    private func restoreRemotePresentationSource(_ machine: RemoteMachine) {
        let restoredSecret = machine.secret?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.controller = machine.controllerAddress
        self.controllerSecret = restoredSecret?.isEmpty == false ? restoredSecret : nil
        self.externalControllerDisplay = machine.displayAddress
        self.controllerUIURL = self.makeControllerUIURL(machine.controllerAddress)
        self.ensureAPIClient()

        self.lastSyncedEditableSettings = nil
        self.preserveLocalSettingsOnNextSync = false
        self.pendingAppLaunchOverlaySettings = nil
    }
}
