import AppKit
import Foundation

@MainActor
extension AppSession {
    var coreDirectoryPath: String {
        self.workingDirectoryManager.coreDirectoryURL.path
    }

    var hasDetectedCoreBinary: Bool {
        if self.coreRepository.isRunning {
            return true
        }

        if self.hasInstalledManagedMihomoCore() {
            return true
        }

        return self.bundlesMihomoCore
    }

    func refreshDetectedCoreStatus() {
        self.mihomoBinaryPath = self.coreRepository.detectedBinaryPath ?? "-"
    }

    func hasInstalledManagedMihomoCore() -> Bool {
        FileManager.default.fileExists(atPath: workingDirectoryManager.managedMihomoBinaryURL.path)
    }

    func shouldDeferAutoStartForMissingManagedCore() -> Bool {
        !bundlesMihomoCore && !self.hasInstalledManagedMihomoCore()
    }

    func coreErrorMessage(_ error: Error) -> String {
        if let binaryResolutionError = error as? MihomoBinaryResolutionError {
            switch binaryResolutionError {
            case let .binaryNotFound(expectedDirectory):
                return tr("app.core.error.binary_not_found", expectedDirectory)
            }
        }

        return error.localizedDescription
    }

    func presentInitialNoCoreSetupGuideIfNeeded() {
        guard self.shouldPresentInitialNoCoreSetupGuide() else { return }
        guard !didPresentInitialNoCoreSetupGuide else { return }

        didPresentInitialNoCoreSetupGuide = true
        defaults.set(true, forKey: initialNoCoreSetupGuideShownKey)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = tr("app.core.setup_required.title")
        alert.informativeText = tr("app.core.setup_required.message", self.coreDirectoryPath)
        alert.addButton(withTitle: tr("ui.action.open_core_directory"))
        alert.addButton(withTitle: tr("ui.action.ok"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)

        if alert.runModal() == .alertFirstButtonReturn {
            self.showCoreDirectoryInFinder()
        }
    }

    func shouldPresentInitialNoCoreSetupGuide() -> Bool {
        guard self.shouldDeferAutoStartForMissingManagedCore() else { return false }
        guard !defaults.bool(forKey: initialNoCoreSetupGuideShownKey) else { return false }
        return true
    }
}
