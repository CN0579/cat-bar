@MainActor
extension AppSession {
    private func proxyRuntimeConfigRepository(using transport: any MihomoAPITransporting) -> RuntimeConfigRepository {
        DefaultRuntimeConfigRepository(transport: transport)
    }

    private func proxyRepository(using transport: any MihomoAPITransporting) -> ProxyRepository {
        DefaultProxyRepository(transport: transport)
    }

    private func switchCoreModeUseCase() throws -> SwitchCoreModeUseCase {
        try SwitchCoreModeUseCase(repository: self.proxyRuntimeConfigRepository(using: self.modeSwitchTransport()))
    }

    private func patchRuntimeConfigUseCase() throws -> PatchRuntimeConfigUseCase {
        try PatchRuntimeConfigUseCase(repository: self.proxyRuntimeConfigRepository(using: self.clientOrThrow()))
    }

    private func switchProxyNodeUseCase() throws -> SwitchProxyNodeUseCase {
        try SwitchProxyNodeUseCase(repository: self.proxyRepository(using: self.clientOrThrow()))
    }

    private func measureGroupLatencyUseCase() throws -> MeasureGroupLatencyUseCase {
        try MeasureGroupLatencyUseCase(repository: self.proxyRepository(using: self.clientOrThrow()))
    }

    func switchMode(to target: CoreMode) async {
        if !isModeSwitchEnabled || modeSwitchInFlight || target == currentMode { return }
        modeSwitchInFlight = true
        defer { modeSwitchInFlight = false }

        // Optimistic UI update: keep interaction snappy, polling will reconcile if server differs.
        currentMode = target

        do {
            try await self.switchCoreModeUseCase().execute(mode: target)
        } catch {
            // Intentional no-op: mode switch failures stay silent by product decision.
        }
    }

    func toggleSystemProxy(_ enabled: Bool) async {
        isProxySyncing = true
        self.systemProxyEnableIntentInFlight = enabled
        self.clearSystemProxyOpenFailureHint()
        defer { isProxySyncing = false }
        defer { self.systemProxyEnableIntentInFlight = false }

        do {
            if enabled {
                let target = try await resolveSystemProxyTargetFromRuntimeConfig()
                try await applySystemProxy(enabled: true, host: target.host, ports: target.ports)
                systemProxyActiveDisplay = self.buildSystemProxyDisplayString(host: target.host, ports: target.ports)
            } else {
                try await applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
                systemProxyActiveDisplay = nil
            }

            // Keep a core-side sync call so proxy toggle and runtime config stay aligned.
            try await self.patchRuntimeConfigUseCase().execute(body: ["mode": .string(currentMode.rawValue)])

            isSystemProxyEnabled = enabled
            self.clearSystemProxyOpenFailureHint()
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
            if enabled {
                await self.refreshSystemProxyHelperRuntimeSnapshot()
            } else {
                self.resetSystemProxyObservedState()
            }
            let state = enabled ? tr("log.system_proxy.enabled") : tr("log.system_proxy.disabled")
            appendLog(level: "info", message: tr("log.system_proxy.toggled", state))
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.toggle_failed", systemProxyErrorMessage(error)))
            if enabled {
                self.updateSystemProxyOpenFailureHint(for: error)
            }
            await self.refreshSystemProxyHelperStatus()
            if enabled || self.isSystemProxyEnabled {
                await refreshSystemProxyStatus()
            } else {
                self.resetSystemProxyObservedState()
            }
        }
    }

    func copyProxyCommand() {
        self.copyLocalProxyCommand()
    }

    func copyLocalProxyCommand() {
        self.copyProxyCommand(host: "127.0.0.1")
    }

    func copyManagedEndpointProxyCommand() {
        self.copyProxyCommand(host: self.managedEndpointProxyCommandHost())
    }

    func localProxyCommandTargetDisplay() -> String {
        let ports = currentSystemProxyPortsFromState()
        return self.buildSystemProxyDisplayString(host: "127.0.0.1", ports: ports) ?? "127.0.0.1"
    }

    func localProxyCommandHostDisplay() -> String {
        "127.0.0.1"
    }

    func managedEndpointProxyCommandTargetDisplay() -> String {
        let ports = currentSystemProxyPortsFromState()
        let host = self.managedEndpointProxyCommandHost()
        return self.buildSystemProxyDisplayString(host: host, ports: ports) ?? host
    }

    func managedEndpointProxyCommandHostDisplay() -> String {
        self.managedEndpointProxyCommandHost()
    }

    private func copyProxyCommand(host: String) {
        let ports = currentSystemProxyPortsFromState()
        let httpPort = ports.httpPort ?? ports.socksPort ?? effectiveMixedPort()
        let socksPort = ports.socksPort ?? ports.httpPort ?? httpPort
        let script = BuildTerminalProxyCommandUseCase().execute(host: host, httpPort: httpPort, socksPort: socksPort)
        copyTextToPasteboard(script)
        appendLog(level: "info", message: tr("log.proxy_export.copied"))
    }

    func switchProxy(group: String, target: String) async {
        await runNoResponseAction(tr("log.action_name.switch_proxy", group, target)) {
            try await self.switchProxyNodeUseCase().execute(group: group, target: target)
            await self.refreshProxyGroups()
        }
    }

    func refreshGroupLatency(_ group: ProxyGroup) async {
        groupLatencyLoading.insert(group.name)
        defer { groupLatencyLoading.remove(group.name) }

        let testURL = normalizedHealthcheckURL(group.testUrl) ?? defaultHealthcheckURL
        let timeout = normalizedHealthcheckTimeout(group.timeout) ?? defaultHealthcheckTimeoutMilliseconds
        await runRefresh {
            let response = try await self.measureGroupLatencyUseCase().execute(
                group: group.name,
                url: testURL,
                timeout: timeout)
            let delays = self.normalizedMeasuredDelays(response.values)

            self.groupLatencies[group.name] = delays
            self.recordMeasuredProxyDelays(delays, useProxyIdentityLookup: true)
        }
    }

    func testSingleNodeLatency(
        nodeName: String,
        testURL: String? = nil,
        timeout: Int? = nil) async -> Int?
    {
        let url = normalizedHealthcheckURL(testURL) ?? defaultHealthcheckURL
        let resolvedTimeout = normalizedHealthcheckTimeout(timeout) ?? defaultHealthcheckTimeoutMilliseconds
        do {
            let repo = try self.proxyRepository(using: self.clientOrThrow())
            let result = try await repo.measureNodeLatency(name: nodeName, url: url, timeout: resolvedTimeout)
            let delay = max(result.delay, 0)
            self.recordMeasuredProxyDelays([nodeName: delay], useProxyIdentityLookup: true)
            return delay
        } catch {
            self.recordMeasuredProxyDelays([nodeName: 0], useProxyIdentityLookup: true)
            return 0
        }
    }

    func testSingleNodeLatencyWithLoading(
        nodeName: String,
        groupName: String? = nil,
        testURL: String? = nil,
        timeout: Int? = nil) async
    {
        nodeLatencyLoading.insert(nodeName)
        defer { nodeLatencyLoading.remove(nodeName) }
        
        let delay = await self.testSingleNodeLatency(
            nodeName: nodeName,
            testURL: testURL,
            timeout: timeout)
            
        if let groupName = groupName, let finalDelay = delay {
            if self.groupLatencies[groupName] == nil {
                self.groupLatencies[groupName] = [:]
            }
            self.groupLatencies[groupName]?[self.proxyDelayLookupKey(nodeName: nodeName)] = finalDelay
        }
    }

    func refreshAllGroupLatencies(includeHiddenGroups: Bool = false) async {
        let groups = includeHiddenGroups
            ? proxyGroups
            : proxyGroups.filter { $0.hidden != true }
        await withTaskGroup(of: Void.self) { taskGroup in
            for group in groups {
                taskGroup.addTask { [weak self] in
                    await self?.refreshGroupLatency(group)
                }
            }
        }
    }

    func delayText(group: String, node: String, fallbackToGroupHistory: Bool = false) -> String {
        guard let value = delayValue(
            group: group,
            node: node,
            fallbackToGroupHistory: fallbackToGroupHistory)
        else { return tr("ui.common.unknown") }
        if value == 0 { return tr("ui.common.timeout") }
        return tr("ui.common.latency_ms", value)
    }

    func delayValue(group: String, node: String, fallbackToGroupHistory: Bool = false) -> Int? {
        self.resolvedDelayValue(
            currentGroup: group,
            proxyName: node,
            fallbackGroupName: fallbackToGroupHistory ? group : nil,
            visitedGroups: [group])
    }

    func latestDelay(for proxyName: String, nodeID: String? = nil) -> Int? {
        let key = self.proxyDelayLookupKey(nodeName: proxyName, nodeID: nodeID)
        return self.liveProxyLatestDelay[key] ?? self.proxyHistoryLatestDelay[key]
    }

    func clearMeasuredProxyDelays() {
        self.groupLatencies = [:]
        self.liveProxyLatestDelay = [:]
        self.proxyHistoryLatestDelay = [:]
    }

    private func recordMeasuredProxyDelays(_ delays: [String: Int]) {
        guard !delays.isEmpty else { return }
        self.recordMeasuredProxyDelays(delays, useProxyIdentityLookup: false)
    }

    private func recordMeasuredProxyDelays(_ delays: [String: Int], useProxyIdentityLookup: Bool) {
        guard !delays.isEmpty else { return }
        for (name, delay) in delays {
            let key = useProxyIdentityLookup
                ? self.proxyDelayLookupKey(nodeName: name)
                : name
            self.liveProxyLatestDelay[key] = max(delay, 0)
        }
    }

    private func normalizedMeasuredDelays(_ delays: [String: Int]) -> [String: Int] {
        delays.reduce(into: [:]) { partialResult, entry in
            let key = self.proxyDelayLookupKey(nodeName: entry.key)
            partialResult[key] = max(entry.value, 0)
        }
    }

    private func proxyDelayLookupKey(nodeName: String, nodeID: String? = nil) -> String {
        nodeID?.trimmedNonEmpty ?? self.proxyNodeIDs[nodeName] ?? nodeName
    }

    private func resolvedDelayValue(
        currentGroup: String,
        proxyName: String,
        fallbackGroupName: String?,
        visitedGroups: Set<String>) -> Int?
    {
        let nodeDelayKey = self.proxyDelayLookupKey(nodeName: proxyName)
        if let liveValue = groupLatencies[currentGroup]?[nodeDelayKey] {
            return liveValue
        }

        if let referencedGroup = self.proxyGroup(named: proxyName),
           !visitedGroups.contains(referencedGroup.name)
        {
            let nextVisitedGroups = visitedGroups.union([referencedGroup.name])
            if let nestedNode = referencedGroup.now?.trimmedNonEmpty,
               let resolvedNestedDelay = self.resolvedDelayValue(
                   currentGroup: referencedGroup.name,
                   proxyName: nestedNode,
                   fallbackGroupName: referencedGroup.name,
                   visitedGroups: nextVisitedGroups)
            {
                return resolvedNestedDelay
            }

            if let referencedGroupDelay = self.groupDelayValue(for: referencedGroup.name) {
                return referencedGroupDelay
            }
        }

        if let liveValue = latestDelay(for: proxyName, nodeID: self.proxyNodeIDs[proxyName]) {
            return liveValue
        }

        if let fallbackGroupName {
            return self.groupDelayValue(for: fallbackGroupName)
        }

        return nil
    }

    private func groupDelayValue(for groupName: String) -> Int? {
        let key = self.proxyDelayLookupKey(nodeName: groupName)
        return self.liveProxyLatestDelay[key]
            ?? self.proxyHistoryLatestDelay[key]
            ?? self.liveProxyLatestDelay[groupName]
            ?? self.proxyHistoryLatestDelay[groupName]
    }

    private func proxyGroup(named name: String) -> ProxyGroup? {
        self.proxyGroups.first { $0.name == name }
    }

    func controllerHost() -> String {
        guard let host = controllerHost(from: controller), !host.isEmpty else {
            return "127.0.0.1"
        }
        return host
    }

    private func managedEndpointProxyCommandHost() -> String {
        guard !self.isRemoteTarget else {
            return self.controllerHost()
        }

        let configuredHost = self.controllerHost(from: self.localExternalControllerDisplay) ?? self.controllerHost()
        guard self.settingsAllowLan else {
            return configuredHost
        }
        guard self.shouldUseCurrentDeviceIPv4ForProxyCommand(host: configuredHost) else {
            return configuredHost
        }

        return DeviceIPv4AddressResolver.currentAddress() ?? self.controllerHost()
    }

    private func shouldUseCurrentDeviceIPv4ForProxyCommand(host: String) -> Bool {
        switch host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "localhost", "127.0.0.1", "::1", "0.0.0.0", "::", "0:0:0:0:0:0:0:0":
            true
        default:
            false
        }
    }

    func buildSystemProxyDisplayString(host: String, ports: SystemProxyPorts) -> String? {
        guard let port = ports.primaryPort, port > 0 else { return nil }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            return "[\(trimmedHost)]:\(port)"
        }
        return "\(trimmedHost):\(port)"
    }

    func makeControllerUIURL(_ controller: String) -> String {
        "\(normalizedControllerAddress(controller))/ui"
    }
}
