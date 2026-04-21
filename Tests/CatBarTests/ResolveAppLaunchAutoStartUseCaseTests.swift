import XCTest
@testable import CatBar

final class ResolveAppLaunchAutoStartUseCaseTests: XCTestCase {
    private let useCase = ResolveAppLaunchAutoStartUseCase()

    func testExecuteSchedulesWhenLaunchShouldRestoreRunningLocalCore() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            shouldRestoreRunningCoreOnLaunch: true,
            isRemoteTarget: false,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .schedule)
    }

    func testExecuteSkipsWhenBackgroundRefreshIsDisabled() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: false,
            shouldRestoreRunningCoreOnLaunch: true,
            isRemoteTarget: false,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteSkipsWhenLaunchShouldNotRestoreRunningCore() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            shouldRestoreRunningCoreOnLaunch: false,
            isRemoteTarget: false,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteSkipsWhenRemoteTargetIsActive() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            shouldRestoreRunningCoreOnLaunch: true,
            isRemoteTarget: true,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteSkipsWhenManagedCoreIsMissing() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            shouldRestoreRunningCoreOnLaunch: true,
            isRemoteTarget: false,
            shouldDeferForMissingManagedCore: true))

        XCTAssertEqual(decision, .skip)
    }
}
