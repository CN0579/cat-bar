import Foundation

@MainActor
final class DependencyContainer {
    let appSession: AppSession
    let appUpdater: AppUpdater

    init(
        appSession: AppSession = AppSession(),
        appUpdater: AppUpdater = AppUpdater())
    {
        self.appSession = appSession
        self.appUpdater = appUpdater
    }
}
