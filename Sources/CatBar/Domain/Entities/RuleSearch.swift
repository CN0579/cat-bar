import Foundation

enum RuleSearchSubjectKind: String, Sendable {
    case domain
    case ip
}

struct RuleSearchSubject: Equatable, Sendable {
    let rawInput: String
    let normalizedInput: String
    let kind: RuleSearchSubjectKind
    let ipAddress: IPAddressBytes?
}

struct LocalRuleSearchMatch: Equatable, Sendable {
    let subject: RuleSearchSubject
    let ruleIndex: Int
    let policy: String
    let matchedRuleType: String
    let matchedRulePayload: String?
    let providerName: String?
    let providerPath: String?
    let providerRuleType: String?
    let providerRulePayload: String?
}

struct LocalRuleSearchResult: Equatable, Sendable {
    let subject: RuleSearchSubject
    let matches: [LocalRuleSearchMatch]

    var effectiveMatch: LocalRuleSearchMatch? {
        self.matches.first
    }

    var shadowedMatches: [LocalRuleSearchMatch] {
        guard self.matches.count > 1 else { return [] }
        return self.matches.dropFirst().filter { $0.matchedRuleType != "MATCH" }
    }
}

enum LocalRuleSearchError: LocalizedError, Equatable, Sendable {
    case invalidInput
    case missingConfig

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            "The input is not a valid domain or IP address."
        case .missingConfig:
            "No local config file is selected."
        }
    }
}

enum RuleSearchPresentationState: Equatable, Sendable {
    case idle
    case searching
    case invalidInput
    case missingConfig
    case noMatch(RuleSearchSubject)
    case matched(LocalRuleSearchResult)
    case failed(String)
}
