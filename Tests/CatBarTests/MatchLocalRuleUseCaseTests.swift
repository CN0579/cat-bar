import Foundation
import XCTest
@testable import CatBar

final class MatchLocalRuleUseCaseTests: XCTestCase {
    func testExecuteMatchesDirectDomainRuleBeforeProviderRule() throws {
        let workspace = try self.makeWorkspace()
        let configURL = workspace.configDirectory.appendingPathComponent("sample.yaml")
        let providerURL = workspace.rootDirectory.appendingPathComponent("rule/Proxy.yaml")

        try FileManager.default.createDirectory(at: providerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        payload:
          - DOMAIN-SUFFIX,openai.com
        """.write(to: providerURL, atomically: true, encoding: .utf8)

        try """
        rule-providers:
          Proxy:
            type: http
            behavior: classical
            path: ./rule/Proxy.yaml
        rules:
          - DOMAIN,api.openai.com,DIRECT
          - RULE-SET,Proxy,ProxyGroup
          - MATCH,Fallback
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let result = try MatchLocalRuleUseCase().execute(
            input: "api.openai.com",
            configPath: configURL.path)
        let match = result?.effectiveMatch

        XCTAssertEqual(match?.policy, "DIRECT")
        XCTAssertEqual(match?.matchedRuleType, "DOMAIN")
        XCTAssertNil(match?.providerName)
        XCTAssertEqual(result?.matches.count, 3)
    }

    func testExecuteMatchesRuleSetAndReturnsProviderDetails() throws {
        let workspace = try self.makeWorkspace()
        let configURL = workspace.configDirectory.appendingPathComponent("sample.yaml")
        let providerURL = workspace.rootDirectory.appendingPathComponent("rule/OpenAI.yaml")

        try FileManager.default.createDirectory(at: providerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        payload:
          - DOMAIN-SUFFIX,openai.com
          - DOMAIN,chatgpt.com
        """.write(to: providerURL, atomically: true, encoding: .utf8)

        try """
        rule-providers:
          OpenAI: { type: http, behavior: classical, path: ./rule/OpenAI.yaml }
        rules:
          - RULE-SET,OpenAI,AI
          - MATCH,DIRECT
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let result = try MatchLocalRuleUseCase().execute(
            input: "api.openai.com",
            configPath: configURL.path)
        let match = result?.effectiveMatch

        XCTAssertEqual(match?.policy, "AI")
        XCTAssertEqual(match?.matchedRuleType, "RULE-SET")
        XCTAssertEqual(match?.matchedRulePayload, "OpenAI")
        XCTAssertEqual(match?.providerName, "OpenAI")
        XCTAssertEqual(match?.providerRuleType, "DOMAIN-SUFFIX")
        XCTAssertEqual(match?.providerRulePayload, "openai.com")
        XCTAssertEqual(match?.providerPath, "./rule/OpenAI.yaml")
        XCTAssertEqual(result?.matches.count, 2)
    }

    func testExecuteMatchesIPv4CIDRRule() throws {
        let workspace = try self.makeWorkspace()
        let configURL = workspace.configDirectory.appendingPathComponent("sample.yaml")

        try """
        rules:
          - IP-CIDR,1.1.1.0/24,DIRECT
          - MATCH,Proxy
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let result = try MatchLocalRuleUseCase().execute(
            input: "1.1.1.20",
            configPath: configURL.path)
        let match = result?.effectiveMatch

        XCTAssertEqual(match?.policy, "DIRECT")
        XCTAssertEqual(match?.matchedRuleType, "IP-CIDR")
        XCTAssertEqual(match?.matchedRulePayload, "1.1.1.0/24")
    }

    func testExecuteCollectsAllMatchesAndKeepsFirstAsEffective() throws {
        let workspace = try self.makeWorkspace()
        let configURL = workspace.configDirectory.appendingPathComponent("sample.yaml")
        let firstProviderURL = workspace.rootDirectory.appendingPathComponent("rule/First.yaml")
        let secondProviderURL = workspace.rootDirectory.appendingPathComponent("rule/Second.yaml")

        try FileManager.default.createDirectory(
            at: firstProviderURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try "payload:\n  - DOMAIN-SUFFIX,example.com\n".write(
            to: firstProviderURL,
            atomically: true,
            encoding: .utf8)
        try "payload:\n  - DOMAIN-KEYWORD,example\n".write(
            to: secondProviderURL,
            atomically: true,
            encoding: .utf8)

        try """
        rule-providers:
          First: { type: http, behavior: classical, path: ./rule/First.yaml }
          Second: { type: http, behavior: classical, path: ./rule/Second.yaml }
        rules:
          - RULE-SET,First,FirstPolicy
          - DOMAIN-SUFFIX,example.com,LocalPolicy
          - RULE-SET,Second,SecondPolicy
          - MATCH,Fallback
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let result = try MatchLocalRuleUseCase().execute(
            input: "api.example.com",
            configPath: configURL.path)

        XCTAssertEqual(result?.effectiveMatch?.policy, "FirstPolicy")
        XCTAssertEqual(result?.matches.map(\.policy), ["FirstPolicy", "LocalPolicy", "SecondPolicy", "Fallback"])
        XCTAssertEqual(result?.shadowedMatches.map(\.policy), ["LocalPolicy", "SecondPolicy"])
    }

    func testExecuteThrowsForInvalidInput() throws {
        let workspace = try self.makeWorkspace()
        let configURL = workspace.configDirectory.appendingPathComponent("sample.yaml")
        try "rules:\n  - MATCH,DIRECT\n".write(to: configURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try MatchLocalRuleUseCase().execute(input: "not a host,", configPath: configURL.path))
        { error in
            XCTAssertEqual(error as? LocalRuleSearchError, .invalidInput)
        }
    }

    private func makeWorkspace() throws -> (rootDirectory: URL, configDirectory: URL) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configDirectory = rootDirectory.appendingPathComponent("config", isDirectory: true)
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        self.addTeardownBlock {
            if FileManager.default.fileExists(atPath: rootDirectory.path) {
                try FileManager.default.removeItem(at: rootDirectory)
            }
        }
        return (rootDirectory, configDirectory)
    }
}
