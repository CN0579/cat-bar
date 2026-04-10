import XCTest
@testable import CatBar

final class ProxyGroupPresentationStateTests: XCTestCase {
    func testSettingProxyGroupsKeepsIndexInSyncImmediately() {
        var state = ProxyGroupPresentationState()

        state.proxyGroups = [
            ProxyGroup(name: "A", all: ["n1"], hidden: false, latestDelay: 10),
            ProxyGroup(name: "B", all: ["n2"], hidden: false, latestDelay: 20),
        ]

        XCTAssertEqual(state.group(named: "A")?.all, ["n1"])
        XCTAssertEqual(state.group(named: "B")?.all, ["n2"])
    }

    func testRebuildGroupIndexKeepsLatestGroupForDuplicateName() {
        var state = ProxyGroupPresentationState(
            proxyGroups: [
                ProxyGroup(name: "GLOBAL", all: ["A"], hidden: false, latestDelay: 10),
                ProxyGroup(name: "GLOBAL", all: ["B"], hidden: false, latestDelay: 20),
            ],
            proxyGroupIndicesByName: [:],
            proxyHistoryLatestDelay: [:],
            proxyNodeTypes: [:],
            proxyNodeIDs: [:])

        state.rebuildGroupIndex()

        XCTAssertEqual(state.group(named: "GLOBAL")?.all, ["B"])
        XCTAssertEqual(state.group(named: "GLOBAL")?.latestDelay, 20)
    }

    func testClearRemovesGroupsIndexAndMetadata() {
        var state = ProxyGroupPresentationState(
            proxyGroups: [ProxyGroup(name: "GLOBAL", all: ["A"], hidden: false)],
            proxyGroupIndicesByName: ["GLOBAL": 0],
            proxyHistoryLatestDelay: ["GLOBAL": 20],
            proxyNodeTypes: ["A": "ss"],
            proxyNodeIDs: ["A": "id-a"])

        state.clear(keepingCapacity: false)

        XCTAssertTrue(state.proxyGroups.isEmpty)
        XCTAssertNil(state.group(named: "GLOBAL"))
        XCTAssertTrue(state.proxyHistoryLatestDelay.isEmpty)
        XCTAssertTrue(state.proxyNodeTypes.isEmpty)
        XCTAssertTrue(state.proxyNodeIDs.isEmpty)
    }
}
