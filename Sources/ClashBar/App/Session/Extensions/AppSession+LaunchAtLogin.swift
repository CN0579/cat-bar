import Foundation

@MainActor
extension AppSession {
    private var launchAtLoginApprovalMonitorMaxAttempts: Int {
        300
    }

    private var launchAtLoginApprovalMonitorIntervalNanoseconds: UInt64 {
        1_000_000_000
    }

    private var readLaunchAtLoginEnabledUseCase: ReadLaunchAtLoginEnabledUseCase {
        ReadLaunchAtLoginEnabledUseCase(repository: self.launchAtLoginRepository)
    }

    private var setLaunchAtLoginEnabledUseCase: SetLaunchAtLoginEnabledUseCase {
        SetLaunchAtLoginEnabledUseCase(repository: self.launchAtLoginRepository)
    }

    func refreshLaunchAtLoginStatus() {
        let isEnabled = self.readLaunchAtLoginEnabledUseCase.execute()
        launchAtLoginEnabled = isEnabled

        if isEnabled {
            launchAtLoginErrorMessage = nil
            self.cancelLaunchAtLoginApprovalMonitoring()
        }
    }

    func applyLaunchAtLogin(_ enabled: Bool) {
        self.cancelLaunchAtLoginApprovalMonitoring()
        launchAtLoginErrorMessage = nil

        do {
            launchAtLoginEnabled = try self.setLaunchAtLoginEnabledUseCase.execute(enabled)
            if launchAtLoginEnabled {
                launchAtLoginErrorMessage = nil
            }
        } catch {
            launchAtLoginEnabled = self.readLaunchAtLoginEnabledUseCase.execute()
            launchAtLoginErrorMessage = self.launchAtLoginMessage(for: error)
            self.startLaunchAtLoginApprovalMonitoringIfNeeded(for: error)
            appendLog(level: "error", message: tr("log.launch_at_login.toggle_failed", error.localizedDescription))
        }
    }

    private func startLaunchAtLoginApprovalMonitoringIfNeeded(for error: Error) {
        guard let launchError = error as? AppLaunchServiceError,
              case .requiresApproval = launchError
        else { return }
        guard self.launchAtLoginApprovalMonitorTask == nil else { return }

        self.launchAtLoginApprovalMonitorTask = Task { [weak self] in
            guard let self else { return }
            defer { self.launchAtLoginApprovalMonitorTask = nil }

            for _ in 0..<self.launchAtLoginApprovalMonitorMaxAttempts {
                if self.readLaunchAtLoginEnabledUseCase.execute() {
                    self.launchAtLoginEnabled = true
                    self.launchAtLoginErrorMessage = nil
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: self.launchAtLoginApprovalMonitorIntervalNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private func cancelLaunchAtLoginApprovalMonitoring() {
        self.launchAtLoginApprovalMonitorTask?.cancel()
        self.launchAtLoginApprovalMonitorTask = nil
    }

    private func launchAtLoginMessage(for error: Error) -> String {
        guard let launchError = error as? AppLaunchServiceError else {
            return error.localizedDescription
        }

        switch launchError {
        case .unsupportedEnvironment:
            return tr("app.launch_at_login.error.unsupported_environment")
        case .requiresApproval:
            return tr("app.launch_at_login.error.requires_approval")
        case let .registrationFailed(message):
            return tr("app.launch_at_login.error.register_failed", message)
        case let .unregistrationFailed(message):
            return tr("app.launch_at_login.error.unregister_failed", message)
        }
    }
}
