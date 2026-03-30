import Foundation

@MainActor
extension AppSession {
    private enum ProviderCollectionKind {
        case proxy
        case rule
    }

    private struct ProviderRefreshStatusUpdate {
        let phase: ProviderRefreshPhase
        let trigger: ProviderRefreshTrigger?
        let progressDone: Int
        let progressTotal: Int
        let message: String?
        let generation: Int
    }

    private func providersRepository() throws -> ProvidersRepository {
        try DefaultProvidersRepository(transport: self.clientOrThrow())
    }

    private func fetchProvidersAndRulesUseCase() throws -> FetchProvidersAndRulesUseCase {
        try FetchProvidersAndRulesUseCase(repository: self.providersRepository())
    }

    private func updateProxyProviderUseCase() throws -> UpdateProxyProviderUseCase {
        try UpdateProxyProviderUseCase(repository: self.providersRepository())
    }

    private func updateRuleProviderUseCase() throws -> UpdateRuleProviderUseCase {
        try UpdateRuleProviderUseCase(repository: self.providersRepository())
    }

    private func reloadProvidersConfigUseCase() throws -> ReloadProvidersConfigUseCase {
        try ReloadProvidersConfigUseCase(repository: self.providersRepository())
    }

    func updateRuleProvider(name: String) async {
        guard !self.ruleProviderUpdating.contains(name) else { return }
        self.ruleProviderUpdating.insert(name)
        defer { self.ruleProviderUpdating.remove(name) }

        _ = await self.runSingleProviderUpdate(
            name: name,
            kind: .rule,
            actionName: tr("log.action_name.update_rule_provider", name),
            operation: {
                try await self.performRuleProviderUpdate(name: name)
            })
    }

    func updateRuleProviders(names: [String], actionName: String) async {
        let pendingNames = names.filter { !self.ruleProviderUpdating.contains($0) }
        guard !pendingNames.isEmpty else { return }

        let insertedNames = Set(pendingNames)
        self.ruleProviderUpdating.formUnion(insertedNames)
        defer { self.ruleProviderUpdating.subtract(insertedNames) }

        var succeededNames: [String] = []
        self.ensureAPIClient()
        let result = await self.updateProvidersSequential(
            names: pendingNames,
            operation: { name in
                try await self.performRuleProviderUpdate(name: name)
                succeededNames.append(name)
            },
            onError: { name, error in
                tr("log.providers.rule_update_failed", name, error.localizedDescription)
            })

        await self.refreshProvidersAndRules()

        if result.failed == 0 {
            self.appendLog(level: "info", message: tr("log.action.success", actionName))
        } else {
            self.appendLog(
                level: succeededNames.isEmpty ? "error" : "warning",
                message: tr(
                    "log.action.failed",
                    actionName,
                    succeededNames.isEmpty
                        ? tr("app.provider_refresh.failed")
                        : tr("app.provider_refresh.partial_failed", result.failed)))
        }
    }

    func refreshRuleProviders() async {
        guard !isRuleProvidersRefreshing else { return }
        isRuleProvidersRefreshing = true
        defer { isRuleProvidersRefreshing = false }

        let insertedNames: Set<String>
        do {
            let summary = try await self.providersRepository().fetchRuleProviders()
            let names = summary.providers.keys.sorted()
            insertedNames = Set(names).subtracting(self.ruleProviderUpdating)
            self.ruleProviderUpdating.formUnion(insertedNames)
            _ = await self.updateProvidersSequential(
                names: names,
                operation: { name in
                    try await self.performRuleProviderUpdate(name: name)
                },
                onError: { name, error in
                    tr("log.providers.rule_update_failed", name, error.localizedDescription)
                })
        } catch {
            appendLog(level: "error", message: tr("log.providers.fetch_rule_failed", error.localizedDescription))
            return
        }

        await self.refreshProvidersAndRules()
        self.ruleProviderUpdating.subtract(insertedNames)
    }

    func refreshProxyProviders() async {
        guard !isProxyProvidersRefreshing else { return }
        isProxyProvidersRefreshing = true
        defer { isProxyProvidersRefreshing = false }

        let insertedNames: Set<String>
        do {
            let summary = try await self.providersRepository().fetchProxyProviders()
            let names = summary.providers.keys.sorted()
            insertedNames = Set(names).subtracting(self.providerUpdating)
            self.providerUpdating.formUnion(insertedNames)

            _ = await self.updateProvidersSequential(
                names: names,
                operation: { name in
                    try await self.performProxyProviderUpdate(name: name)
                },
                onError: { name, error in
                    tr("log.providers.proxy_update_failed", name, error.localizedDescription)
                })
        } catch {
            appendLog(level: "error", message: tr("log.providers.fetch_proxy_failed", error.localizedDescription))
            return
        }

        await self.refreshProvidersAndRules()
        self.providerUpdating.subtract(insertedNames)
    }

    func updateProxyProvider(name: String) async {
        guard !providerUpdating.contains(name) else { return }
        providerUpdating.insert(name)
        defer { providerUpdating.remove(name) }

        _ = await self.runSingleProviderUpdate(
            name: name,
            kind: .proxy,
            actionName: tr("log.action_name.update_proxy_provider", name),
            operation: {
                try await self.performProxyProviderUpdate(name: name)
            })
    }

    private func mergedProviderDetailPreservingNodes(
        previous: ProviderDetail?,
        incoming: ProviderDetail) -> ProviderDetail
    {
        let fallbackNodes = incoming.proxies?.map {
            ProviderProxyNode(name: $0.name, latestDelay: $0.latestDelay)
        }
        let merged = incoming.with(proxies: previous?.proxies ?? fallbackNodes)
        guard let preservedUpdatedAt = self.preferredProviderUpdatedAt(
            previous: previous?.updatedAt,
            incoming: incoming.updatedAt)
        else {
            return merged
        }
        return merged.with(updatedAt: preservedUpdatedAt)
    }

    private func shouldIncludeProxyProvider(named key: String, detail: ProviderDetail) -> Bool {
        let resolvedName = detail.name.trimmedNonEmpty ?? key
        if resolvedName.caseInsensitiveCompare("default") == .orderedSame {
            return false
        }

        let vehicleType = detail.vehicleType.trimmedOrEmpty
        return vehicleType.caseInsensitiveCompare("Compatible") != .orderedSame
    }

    func enqueueProviderRefresh(trigger: ProviderRefreshTrigger) {
        self.cancelProviderRefresh(reason: "superseded")
        providerRefreshGeneration += 1
        let generation = providerRefreshGeneration
        providerRefreshTask = Task { [weak self] in
            await self?.runProviderRefreshInBackground(trigger: trigger, generation: generation)
        }
    }

    func cancelProviderRefresh(reason: String) {
        guard providerRefreshTask != nil else { return }
        providerRefreshTask?.cancel()
        providerRefreshTask = nil
        let localizedReason = self.providerRefreshCancelReason(reason)
        self.updateProviderRefreshStatus(
            ProviderRefreshStatusUpdate(
                phase: .cancelled,
                trigger: providerRefreshStatus.trigger,
                progressDone: providerRefreshStatus.progressDone,
                progressTotal: providerRefreshStatus.progressTotal,
                message: tr("app.provider_refresh.cancelled_reason", localizedReason),
                generation: providerRefreshGeneration))
    }

    private func runProviderRefreshInBackground(trigger: ProviderRefreshTrigger, generation: Int) async {
        func checkpoint() -> Bool {
            if Task.isCancelled || generation != providerRefreshGeneration {
                self.updateProviderRefreshStatus(
                    ProviderRefreshStatusUpdate(
                        phase: .cancelled,
                        trigger: trigger,
                        progressDone: providerRefreshStatus.progressDone,
                        progressTotal: providerRefreshStatus.progressTotal,
                        message: tr("app.provider_refresh.cancelled"),
                        generation: generation))
                return false
            }
            return true
        }

        guard checkpoint() else { return }

        func fetchProviderSummary(_ endpoint: Endpoint, onError: (Error) -> String) async -> ProviderSummary {
            do {
                switch endpoint {
                case .proxyProviders:
                    return try await self.providersRepository().fetchProxyProviders()
                case .ruleProviders:
                    return try await self.providersRepository().fetchRuleProviders()
                default:
                    return ProviderSummary(providers: [:])
                }
            } catch {
                appendLog(level: "error", message: onError(error))
                return ProviderSummary(providers: [:])
            }
        }

        let proxyProviders = await fetchProviderSummary(.proxyProviders) {
            tr("log.providers.fetch_proxy_failed", $0.localizedDescription)
        }
        let ruleProviders = await fetchProviderSummary(.ruleProviders) {
            tr("log.providers.fetch_rule_failed", $0.localizedDescription)
        }

        let proxyNames = proxyProviders.providers.keys.sorted()
        let ruleNames = ruleProviders.providers.keys.sorted()
        let total = proxyNames.count + ruleNames.count
        var done = 0
        var failed = 0
        func publishUpdatingProgress() {
            self.updateProviderRefreshStatus(
                ProviderRefreshStatusUpdate(
                    phase: .updating,
                    trigger: trigger,
                    progressDone: done,
                    progressTotal: total,
                    message: tr("app.provider_refresh.updating", done, total),
                    generation: generation))
        }

        publishUpdatingProgress()

        do {
            try await self.reloadProvidersConfigUseCase().execute(force: true)
            appendLog(level: "info", message: tr("log.providers.config_reload_success"))
        } catch {
            failed += 1
            appendLog(level: "error", message: tr("log.providers.config_reload_failed", error.localizedDescription))
        }

        guard checkpoint() else { return }

        let proxyResult = await self.updateProvidersSequential(
            names: proxyNames,
            operation: { name in
                try await self.performProxyProviderUpdate(name: name)
            },
            onError: { name, error in
                tr("log.providers.proxy_update_failed", name, error.localizedDescription)
            },
            shouldContinue: checkpoint,
            onStep: {
                done += 1
                publishUpdatingProgress()
            })
        failed += proxyResult.failed
        guard proxyResult.completed else { return }

        let ruleResult = await self.updateProvidersSequential(
            names: ruleNames,
            operation: { name in
                try await self.performRuleProviderUpdate(name: name)
            },
            onError: { name, error in
                tr("log.providers.rule_update_failed", name, error.localizedDescription)
            },
            shouldContinue: checkpoint,
            onStep: {
                done += 1
                publishUpdatingProgress()
            })
        failed += ruleResult.failed
        guard ruleResult.completed else { return }

        let resultPhase: ProviderRefreshPhase = failed == 0 ? .succeeded : .failed
        let resultMessage = failed == 0
            ? tr("app.provider_refresh.updated")
            : tr("app.provider_refresh.partial_failed", failed)
        self.updateProviderRefreshStatus(
            ProviderRefreshStatusUpdate(
                phase: resultPhase,
                trigger: trigger,
                progressDone: done,
                progressTotal: total,
                message: resultMessage,
                generation: generation))
        providerRefreshTask = nil
    }

    private func updateProviderRefreshStatus(_ update: ProviderRefreshStatusUpdate) {
        guard update.generation == providerRefreshGeneration else { return }
        providerRefreshStatus = ProviderRefreshStatus(
            phase: update.phase,
            trigger: update.trigger,
            progressDone: update.progressDone,
            progressTotal: update.progressTotal,
            message: update.message,
            updatedAt: Date())
    }

    func refreshProvidersAndRules() async {
        await runRefresh {
            let snapshot = try await self.fetchProvidersAndRulesUseCase().execute()
            let proxyProviders = snapshot.proxyProviders
            let ruleProviders = snapshot.ruleProviders
            let rules = snapshot.rules

            let filteredProxyProviders = proxyProviders.providers.filter { key, detail in
                self.shouldIncludeProxyProvider(named: key, detail: detail)
            }

            let previousProxyProviders = self.proxyProvidersDetail
            var nextProxyProviders: [String: ProviderDetail] = [:]
            nextProxyProviders.reserveCapacity(filteredProxyProviders.count)
            for (name, detail) in filteredProxyProviders {
                let merged = self.mergedProviderDetailPreservingNodes(
                    previous: previousProxyProviders[name],
                    incoming: detail)
                nextProxyProviders[name] = merged
            }

            if nextProxyProviders != self.proxyProvidersDetail {
                self.proxyProvidersDetail = nextProxyProviders
            }

            let previousRuleProviders = self.ruleProviders
            let incomingRuleProviders = ruleProviders.providers
            let incomingRuleItems = rules.rules

            var rulesPresentationChanged = false
            var nextRuleProviders: [String: ProviderDetail] = [:]
            nextRuleProviders.reserveCapacity(incomingRuleProviders.count)
            for (name, detail) in incomingRuleProviders {
                let merged: ProviderDetail
                if let preservedUpdatedAt = self.preferredProviderUpdatedAt(
                    previous: previousRuleProviders[name]?.updatedAt,
                    incoming: detail.updatedAt)
                {
                    merged = detail.with(updatedAt: preservedUpdatedAt)
                } else {
                    merged = detail
                }
                nextRuleProviders[name] = merged
            }

            if nextRuleProviders != self.ruleProviders {
                self.ruleProviders = nextRuleProviders
                rulesPresentationChanged = true
            }
            if incomingRuleItems != self.ruleItems {
                self.ruleItems = incomingRuleItems
                rulesPresentationChanged = true
            }
            if rulesPresentationChanged {
                self.noteRulesPresentationChanged()
            }

            let nextProxyCount = filteredProxyProviders.count
            let nextRuleCount = ruleProviders.providers.count
            let nextRulesCount = rules.totalCount
            if self.providerProxyCount != nextProxyCount {
                self.providerProxyCount = nextProxyCount
            }
            if self.providerRuleCount != nextRuleCount {
                self.providerRuleCount = nextRuleCount
            }
            if self.rulesCount != nextRulesCount {
                self.rulesCount = nextRulesCount
            }

            let currentNames = Set(filteredProxyProviders.keys)
            self.providerUpdating = self.providerUpdating.intersection(currentNames)
            if !self.proxyProviderUpdatedAtOverrides.isEmpty {
                self.proxyProviderUpdatedAtOverrides = [:]
            }

            let currentRuleNames = Set(incomingRuleProviders.keys)
            self.ruleProviderUpdating = self.ruleProviderUpdating.intersection(currentRuleNames)
            if !self.ruleProviderUpdatedAtOverrides.isEmpty {
                self.ruleProviderUpdatedAtOverrides = [:]
            }
        }
    }

    private func updateProvidersSequential(
        names: [String],
        operation: (String) async throws -> Void,
        onError: (String, Error) -> String,
        shouldContinue: (() -> Bool)? = nil,
        onStep: (() -> Void)? = nil) async -> (completed: Bool, failed: Int)
    {
        var failed = 0
        for name in names {
            if let shouldContinue, !shouldContinue() {
                return (completed: false, failed: failed)
            }

            do {
                try await operation(name)
            } catch {
                failed += 1
                appendLog(level: "error", message: onError(name, error))
            }
            onStep?()
        }
        return (completed: true, failed: failed)
    }

    private func providerRefreshCancelReason(_ reason: String) -> String {
        switch reason {
        case "stop requested":
            tr("app.provider_refresh.reason.stop_requested")
        case "restart requested":
            tr("app.provider_refresh.reason.restart_requested")
        case "quit requested":
            tr("app.provider_refresh.reason.quit_requested")
        case "config switch requested":
            tr("app.provider_refresh.reason.config_switch_requested")
        case "superseded":
            tr("app.provider_refresh.reason.superseded")
        default:
            reason
        }
    }

    private func runSingleProviderUpdate(
        name: String,
        kind: ProviderCollectionKind,
        actionName: String,
        operation: @escaping () async throws -> Void) async -> Bool
    {
        let previousUpdatedAt = self.providerUpdatedAt(for: name, kind: kind)
        do {
            self.ensureAPIClient()
            try await operation()
            await self.refreshProvidersAndRules()
            await self.refreshProviderUpdatedAtIfNeeded(
                name: name,
                kind: kind,
                previousUpdatedAt: previousUpdatedAt)
            self.appendLog(level: "info", message: tr("log.action.success", actionName))
            return true
        } catch {
            self.appendLog(level: "error", message: tr("log.action.failed", actionName, error.localizedDescription))
            return false
        }
    }

    private func performProxyProviderUpdate(name: String) async throws {
        let previousUpdatedAt = self.providerUpdatedAt(for: name, kind: .proxy)
        do {
            try await self.updateProxyProviderUseCase().execute(name: name)
        } catch {
            guard self.isRequestTimeoutError(error),
                  await self.confirmProviderUpdateAfterTimeout(
                      name: name,
                      kind: .proxy,
                      previousUpdatedAt: previousUpdatedAt)
            else {
                throw error
            }
        }
    }

    private func performRuleProviderUpdate(name: String) async throws {
        let previousUpdatedAt = self.providerUpdatedAt(for: name, kind: .rule)
        do {
            try await self.updateRuleProviderUseCase().execute(name: name)
        } catch {
            guard self.isRequestTimeoutError(error),
                  await self.confirmProviderUpdateAfterTimeout(
                      name: name,
                      kind: .rule,
                      previousUpdatedAt: previousUpdatedAt)
            else {
                throw error
            }
        }
    }

    private func preferredProviderUpdatedAt(previous: String?, incoming: String?) -> String? {
        switch (self.parseProviderUpdatedAt(previous), self.parseProviderUpdatedAt(incoming)) {
        case let (previousDate?, incomingDate?):
            return previousDate >= incomingDate ? previous : incoming
        case (_?, nil):
            return previous
        case (nil, _?):
            return incoming
        case (nil, nil):
            return incoming ?? previous
        }
    }

    private func providerUpdatedAt(for name: String, kind: ProviderCollectionKind) -> String? {
        switch kind {
        case .proxy:
            self.proxyProvidersDetail[name]?.updatedAt
        case .rule:
            self.ruleProviders[name]?.updatedAt
        }
    }

    private func refreshProviderUpdatedAtIfNeeded(
        name: String,
        kind: ProviderCollectionKind,
        previousUpdatedAt: String?) async
    {
        guard !self.didProviderUpdatedAtAdvance(previous: previousUpdatedAt, current: self.providerUpdatedAt(for: name, kind: kind))
        else {
            return
        }

        let confirmed = await self.confirmProviderUpdateAfterTimeout(
            name: name,
            kind: kind,
            previousUpdatedAt: previousUpdatedAt)
        guard confirmed else { return }
        await self.refreshProvidersAndRules()
    }

    private func confirmProviderUpdateAfterTimeout(
        name: String,
        kind: ProviderCollectionKind,
        previousUpdatedAt: String?) async -> Bool
    {
        let retryIntervals: [UInt64] = [0, 250_000_000, 500_000_000, 1_000_000_000]

        for delay in retryIntervals {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                let summary = try await self.fetchProviderSummary(kind: kind)
                let currentUpdatedAt = summary.providers[name]?.updatedAt
                if self.didProviderUpdatedAtAdvance(previous: previousUpdatedAt, current: currentUpdatedAt) {
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }

    private func fetchProviderSummary(kind: ProviderCollectionKind) async throws -> ProviderSummary {
        switch kind {
        case .proxy:
            try await self.providersRepository().fetchProxyProviders()
        case .rule:
            try await self.providersRepository().fetchRuleProviders()
        }
    }

    private func didProviderUpdatedAtAdvance(previous: String?, current: String?) -> Bool {
        let normalizedCurrent = current?.trimmingCharacters(in: .whitespacesAndNewlines)
        return switch (self.parseProviderUpdatedAt(previous), self.parseProviderUpdatedAt(current)) {
        case let (previousDate?, currentDate?):
            currentDate > previousDate
        case (nil, _):
            !(normalizedCurrent?.isEmpty ?? true)
        default:
            false
        }
    }

    private func isRequestTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == URLError.timedOut.rawValue {
            return true
        }

        guard let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error else {
            return false
        }
        return self.isRequestTimeoutError(underlyingError)
    }

    private func parseProviderUpdatedAt(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
