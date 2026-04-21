import Foundation

struct AppLaunchAutoStartContext: Equatable {
    let startBackgroundRefresh: Bool
    let shouldRestoreRunningCoreOnLaunch: Bool
    let isRemoteTarget: Bool
    let shouldDeferForMissingManagedCore: Bool
}

enum AppLaunchAutoStartDecision: Equatable {
    case skip
    case schedule
}

struct ResolveAppLaunchAutoStartUseCase {
    func execute(_ context: AppLaunchAutoStartContext) -> AppLaunchAutoStartDecision {
        guard context.startBackgroundRefresh,
              context.shouldRestoreRunningCoreOnLaunch,
              !context.isRemoteTarget,
              !context.shouldDeferForMissingManagedCore
        else {
            return .skip
        }

        return .schedule
    }
}
