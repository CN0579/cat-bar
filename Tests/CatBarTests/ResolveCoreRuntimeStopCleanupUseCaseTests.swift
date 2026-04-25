import XCTest
@testable import CatBar

final class ResolveCoreRuntimeStopCleanupUseCaseTests: XCTestCase {
    private let useCase = ResolveCoreRuntimeStopCleanupUseCase()

    func testPreservesEnabledFeaturesForFutureRecoveryWhileDisablingHostEffects() {
        let plan = self.useCase.execute(.init(
            preserveFeatureRecovery: true,
            systemProxyEnabled: true,
            tunEnabled: true,
            pendingRecovery: nil))

        XCTAssertEqual(
            plan,
            CoreRuntimeStopCleanupPlan(
                pendingRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true),
                shouldDisableSystemProxy: true,
                shouldDeactivateTunPresentation: true))
    }

    func testMergesExistingPendingRecoveryWhenRuntimeStopsAgain() {
        let plan = self.useCase.execute(.init(
            preserveFeatureRecovery: true,
            systemProxyEnabled: false,
            tunEnabled: true,
            pendingRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: false)))

        XCTAssertEqual(
            plan.pendingRecovery,
            CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true))
        XCTAssertFalse(plan.shouldDisableSystemProxy)
        XCTAssertTrue(plan.shouldDeactivateTunPresentation)
    }

    func testQuitStyleCleanupDoesNotLeaveRecoveryPending() {
        let plan = self.useCase.execute(.init(
            preserveFeatureRecovery: false,
            systemProxyEnabled: true,
            tunEnabled: true,
            pendingRecovery: nil))

        XCTAssertEqual(
            plan,
            CoreRuntimeStopCleanupPlan(
                pendingRecovery: nil,
                shouldDisableSystemProxy: true,
                shouldDeactivateTunPresentation: true))
    }
}
