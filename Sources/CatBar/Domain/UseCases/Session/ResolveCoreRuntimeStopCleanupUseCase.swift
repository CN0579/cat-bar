import Foundation

struct CoreRuntimeStopCleanupContext: Equatable {
    let preserveFeatureRecovery: Bool
    let systemProxyEnabled: Bool
    let tunEnabled: Bool
    let pendingRecovery: CoreFeatureRecoveryState?
}

struct CoreRuntimeStopCleanupPlan: Equatable {
    let pendingRecovery: CoreFeatureRecoveryState?
    let shouldDisableSystemProxy: Bool
    let shouldDeactivateTunPresentation: Bool
}

struct ResolveCoreRuntimeStopCleanupUseCase {
    func execute(_ context: CoreRuntimeStopCleanupContext) -> CoreRuntimeStopCleanupPlan {
        let capturedRecovery = CoreFeatureRecoveryState(
            systemProxyEnabled: context.preserveFeatureRecovery && context.systemProxyEnabled,
            tunEnabled: context.preserveFeatureRecovery && context.tunEnabled)

        let mergedRecovery = capturedRecovery.merged(with: context.pendingRecovery).pendingState

        return CoreRuntimeStopCleanupPlan(
            pendingRecovery: mergedRecovery,
            shouldDisableSystemProxy: context.systemProxyEnabled,
            shouldDeactivateTunPresentation: context.tunEnabled)
    }
}
