import AppKit
import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    private let updaterController: SPUStandardUpdaterController?

    override init() {
        if Self.hasSecureUpdateConfiguration {
            self.updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil)
        } else {
            self.updaterController = nil
        }

        super.init()
    }

    var isConfigured: Bool {
        self.updaterController != nil
    }

    func checkForUpdates() {
        if let updaterController {
            updaterController.checkForUpdates(nil)
            return
        }

        NSWorkspace.shared.open(AppReleaseConfiguration.releasesPageURL)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(AppReleaseConfiguration.releasesPageURL)
    }

    private static var hasSecureUpdateConfiguration: Bool {
        guard
            let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return true
    }
}
