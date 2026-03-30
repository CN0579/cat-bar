import Foundation

@MainActor
extension AppSession {
    func synchronizeRuntimeStatusForActiveTarget(remoteIsReachable: Bool? = nil) {
        switch self.remoteMachineStore.activeTarget {
        case .remote:
            let isRunning = remoteIsReachable ?? (self.apiStatus == .healthy || self.apiStatus == .degraded)
            self.statusText = isRunning ? "Running" : "Stopped"
        case .local:
            if !self.coreRepository.isRunning {
                self.statusText = "Stopped"
            }
        }
    }

    func refreshRemoteTargetAvailabilityForMenuBarIfNeeded() async {
        guard case let .remote(machine) = self.remoteMachineStore.activeTarget else {
            self.synchronizeRuntimeStatusForActiveTarget()
            return
        }

        let status = await self.remoteMachineStore.refreshConnectivity(for: machine)
        switch status {
        case let .connected(version):
            self.version = version
            self.apiStatus = .healthy
            self.synchronizeRuntimeStatusForActiveTarget(remoteIsReachable: true)
            self.startPolling()
        case .unknown, .checking, .failed:
            self.apiStatus = .unknown
            self.synchronizeRuntimeStatusForActiveTarget(remoteIsReachable: false)
        }
    }

    func switchToMachineTarget(_ target: MachineTarget) async {
        if case let .remote(machine) = target {
            let status = await self.remoteMachineStore.refreshConnectivity(for: machine)
            guard status.isConnected else { return }
        }

        self.remoteMachineStore.selectTarget(target)

        self.cancelPolling()
        self.resetTrafficPresentation()
        self.clearAllLogs()
        self.proxyGroups = []
        self.clearMeasuredProxyDelays()
        self.proxyNodeTypes = [:]
        self.proxyNodeIDs = [:]
        self.ruleItems = []
        self.ruleProviders = [:]
        self.noteRulesPresentationChanged()
        self.connectionsStore.clearConnectionsList()
        self.connectionsStore.connectionsCount = 0

        switch target {
        case .local:
            self.appendLog(level: "info", message: self.tr("log.remote.switched_to_local"))
            if let configPath = await self.resolveSelectedConfigPath() {
                self.applyExternalControllerFromSelectedConfigFile(configPath: configPath)
            } else {
                let fallback = "127.0.0.1:9090"
                self.controller = fallback
                self.controllerSecret = nil
                self.externalControllerDisplay = fallback
                self.localExternalControllerDisplay = fallback
                self.controllerUIURL = self.makeControllerUIURL(fallback)
                self.ensureAPIClient()
            }

            if let snapshot = self.loadPersistedEditableSettingsSnapshot() {
                self.applyEditableSettingsSnapshotToUI(snapshot)
                self.preserveLocalSettingsOnNextSync = true
                self.pendingAppLaunchOverlaySettings = snapshot
            }
            self.lastSyncedEditableSettings = nil

        case let .remote(machine):
            self.appendLog(
                level: "info",
                message: self.tr("log.remote.switched_to_remote", machine.name, machine.displayAddress))
            self.controller = machine.controllerAddress
            self.controllerSecret = machine.secret
            self.externalControllerDisplay = machine.displayAddress
            self.controllerUIURL = self.makeControllerUIURL(machine.controllerAddress)
            self.ensureAPIClient()
            self.lastSyncedEditableSettings = nil
            self.preserveLocalSettingsOnNextSync = false
        }

        await self.refreshFromAPI(includeSlowCalls: true)

        if self.lastSyncedEditableSettings == nil {
            _ = try? await self.fetchRuntimeConfigSnapshot()
        }

        if case .local = target {
            await self.applyPendingAppLaunchSettingsOverlayIfNeeded(syncSystemProxyPort: false)
        }

        // Remote targets have no local process, so statusText must be kept in
        // sync with the active controller state for the status-bar icon.
        self.synchronizeRuntimeStatusForActiveTarget()

        if self.apiStatus == .healthy || self.apiStatus == .degraded {
            self.startPolling()
        }
    }
}
