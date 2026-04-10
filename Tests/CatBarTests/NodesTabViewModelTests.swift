import XCTest
@testable import CatBar

@MainActor
final class NodesTabViewModelTests: XCTestCase {
    func testBuildLocalNodesExcludesProviderNodesReservedMarkersAndSortsOutput() {
        let subject = NodesTabViewModel()
        let providers = [
            "Provider": ProviderDetail(
                name: "Provider",
                vehicleType: nil,
                testUrl: nil,
                timeout: nil,
                updatedAt: nil,
                ruleCount: nil,
                subscriptionInfo: nil,
                proxies: [
                    ProviderProxyNode(id: "shared-id", name: "Provider Node", type: "vmess"),
                ]),
        ]

        let result = subject.buildLocalNodes(
            proxyNodeIDs: [
                "Provider Node": "other-id",
                "Duplicate By ID": "shared-id",
                "URL-Test": "url-id",
                "Zulu": "z-id",
                "Alpha": "a-id",
            ],
            proxyNodeTypes: [
                "Provider Node": "vmess",
                "Duplicate By ID": "trojan",
                "URL-Test": "ss",
                "Zulu": "vmess",
                "Alpha": "ss",
            ],
            providerNodeNames: [],
            providerNodeIDs: [],
            proxyProvidersDetail: providers)

        XCTAssertEqual(result.map(\.name), ["Alpha", "Zulu"])
        XCTAssertEqual(result.map(\.stableIdentity), ["a-id", "z-id"])
    }

    func testFilteredProviderNodesMatchesNameAndTypeCaseInsensitively() {
        let subject = NodesTabViewModel()
        let nodes = [
            ProviderProxyNode(name: "Tokyo Relay", type: "vmess"),
            ProviderProxyNode(name: "Osaka", type: "trojan"),
        ]

        XCTAssertEqual(subject.filteredProviderNodes(nodes, searchText: "TOKYO").map(\.name), ["Tokyo Relay"])
        XCTAssertEqual(subject.filteredProviderNodes(nodes, searchText: "tro").map(\.name), ["Osaka"])
    }

    func testFilteredLocalNodesMatchesNameAndTypeCaseInsensitively() {
        let subject = NodesTabViewModel()
        let nodes = [
            NodesTabViewModel.LocalNode(id: nil, name: "HK Relay", type: "vmess"),
            NodesTabViewModel.LocalNode(id: nil, name: "JP Direct", type: "ss"),
        ]

        XCTAssertEqual(subject.filteredLocalNodes(nodes, searchText: "relay").map(\.name), ["HK Relay"])
        XCTAssertEqual(subject.filteredLocalNodes(nodes, searchText: "VME").map(\.name), ["HK Relay"])
    }

    func testBuildPresentedLocalNodesAppliesSearchDuringConstruction() {
        let subject = NodesTabViewModel()

        let result = subject.buildPresentedLocalNodes(
            proxyNodeIDs: [
                "Tokyo Relay": "tokyo-id",
                "Osaka Direct": "osaka-id",
            ],
            proxyNodeTypes: [
                "Tokyo Relay": "vmess",
                "Osaka Direct": "ss",
            ],
            providerNodeNames: [],
            providerNodeIDs: [],
            proxyProvidersDetail: [:],
            matcher: subject.searchMatcher(for: "  relay "))

        XCTAssertEqual(result.map(\.name), ["Tokyo Relay"])
    }

    func testBuildLocalNodesExcludesProviderBackedNodesWithoutProviderDetails() {
        let subject = NodesTabViewModel()

        let result = subject.buildLocalNodes(
            proxyNodeIDs: [
                "Remote Node": "remote-id",
                "Local Node": "local-id",
            ],
            proxyNodeTypes: [
                "Remote Node": "vmess",
                "Local Node": "ss",
            ],
            providerNodeNames: ["Remote Node"],
            providerNodeIDs: ["remote-id"],
            proxyProvidersDetail: [:])

        XCTAssertEqual(result.map(\.name), ["Local Node"])
    }

    func testSearchMatcherTreatsWhitespaceOnlyKeywordAsEmpty() {
        let subject = NodesTabViewModel()

        XCTAssertNil(subject.searchMatcher(for: "   "))
    }
}
