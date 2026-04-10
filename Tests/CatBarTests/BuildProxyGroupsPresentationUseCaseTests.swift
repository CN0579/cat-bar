import XCTest
@testable import CatBar

final class BuildProxyGroupsPresentationUseCaseTests: XCTestCase {
    func testExecuteTracksProviderBackedLeafNodesFromProxyResponse() {
        let subject = BuildProxyGroupsPresentationUseCase()
        let response = ProxyGroupsResponse(proxies: [
            "Provider Group": ProxyGroup(
                name: "Provider Group",
                type: "Selector",
                all: ["Remote Node"],
                providerName: "provider-a"),
            "Remote Node": ProxyGroup(
                id: "remote-id",
                name: "Remote Node",
                type: "vmess",
                all: [],
                providerName: "provider-a"),
            "Local Node": ProxyGroup(
                id: "local-id",
                name: "Local Node",
                type: "ss",
                all: []),
        ])

        let output = subject.execute(response: response, proxyProviders: [:], fallbackProxyProviders: [:])

        XCTAssertEqual(output.providerNodeNames, ["Remote Node"])
        XCTAssertEqual(output.providerNodeIDs, ["remote-id"])
        XCTAssertEqual(output.nodeTypes["Local Node"], "ss")
    }
}
