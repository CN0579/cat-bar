import XCTest
@testable import CatBar

final class ConnectionRulePresentationResolverTests: XCTestCase {
    private let resolver = ConnectionRulePresentationResolver()

    func testParseRuleReadsParenthesizedPayload() {
        let parsed = self.resolver.parseRule("DOMAIN-SUFFIX(google.com)")

        XCTAssertEqual(
            parsed,
            ParsedConnectionRule(type: "DOMAIN-SUFFIX", payload: "google.com"))
    }

    func testParseRuleReadsCommaSeparatedPayload() {
        let parsed = self.resolver.parseRule("IP-CIDR,1.1.1.1/32")

        XCTAssertEqual(
            parsed,
            ParsedConnectionRule(type: "IP-CIDR", payload: "1.1.1.1/32"))
    }

    func testRuleTypeTextHidesMatchAndFinalMarkers() {
        XCTAssertEqual(self.resolver.ruleTypeText(raw: "MATCH", fallback: nil), "--")
        XCTAssertEqual(self.resolver.ruleTypeText(raw: nil, fallback: "FINAL"), "--")
    }

    func testChainsPartsDropsEmptyValuesAndReversesOrder() {
        XCTAssertEqual(
            self.resolver.chainsParts(["Proxy", "  ", "Group"]),
            ["Group", "Proxy"])
    }

    func testMatchesSearchChecksCoreSearchFieldsWithoutBuildingJoinedText() {
        let connection = ConnectionSummary(
            id: "abc",
            upload: 1,
            download: 2,
            start: "2026-01-01T12:00:00Z",
            rule: "DOMAIN-SUFFIX(example.com)",
            rulePayload: "payload",
            chains: ["Proxy", "Group"],
            metadata: ConnectionMetadata(
                network: "tcp",
                sourceIP: "10.0.0.1",
                destinationIP: "1.1.1.1",
                host: "example.com"))

        XCTAssertTrue(self.resolver.matchesSearch(connection, keyword: "example.com"))
        XCTAssertTrue(self.resolver.matchesSearch(connection, keyword: "1.1.1.1"))
        XCTAssertTrue(self.resolver.matchesSearch(connection, keyword: "10.0.0.1"))
        XCTAssertTrue(self.resolver.matchesSearch(connection, keyword: "tcp"))
        XCTAssertTrue(self.resolver.matchesSearch(connection, keyword: "abc"))
        XCTAssertTrue(self.resolver.matchesSearch(connection, keyword: "Group"))
        XCTAssertFalse(self.resolver.matchesSearch(connection, keyword: "missing"))
    }
}
