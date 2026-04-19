import Darwin
import Foundation

struct MatchLocalRuleUseCase: Sendable {
    private let launchContextResolver: MihomoLaunchContextResolver

    init(launchContextResolver: MihomoLaunchContextResolver = MihomoLaunchContextResolver()) {
        self.launchContextResolver = launchContextResolver
    }

    func execute(input: String, configPath: String?) throws -> LocalRuleSearchResult? {
        guard let configPath = configPath?.trimmedNonEmpty else {
            throw LocalRuleSearchError.missingConfig
        }

        guard let subject = Self.normalizeSubject(input) else {
            throw LocalRuleSearchError.invalidInput
        }

        let configURL = URL(fileURLWithPath: configPath).standardizedFileURL
        let workingDirectoryURL = self.launchContextResolver.workingDirectoryURL(for: configPath)
        let parsedConfig = try Self.parseConfig(
            at: configURL,
            workingDirectoryURL: workingDirectoryURL)

        var matches: [LocalRuleSearchMatch] = []
        for (index, rule) in parsedConfig.rules.enumerated() {
            if let providerMatch = try self.matchProviderRule(
                rule,
                index: index,
                subject: subject,
                providerRefs: parsedConfig.providerRefs)
            {
                matches.append(providerMatch)
                continue
            }

            guard self.matches(subject: subject, ruleType: rule.type, payload: rule.payload) else {
                continue
            }

            matches.append(LocalRuleSearchMatch(
                subject: subject,
                ruleIndex: index,
                policy: rule.policy,
                matchedRuleType: rule.type,
                matchedRulePayload: rule.payload,
                providerName: nil,
                providerPath: nil,
                providerRuleType: nil,
                providerRulePayload: nil))
        }

        guard !matches.isEmpty else { return nil }
        return LocalRuleSearchResult(subject: subject, matches: matches)
    }

    private func matchProviderRule(
        _ rule: ParsedMainRule,
        index: Int,
        subject: RuleSearchSubject,
        providerRefs: [String: ParsedRuleProviderRef]) throws -> LocalRuleSearchMatch?
    {
        guard rule.type == "RULE-SET",
              let providerName = rule.payload?.trimmedNonEmpty,
              let providerRef = providerRefs[providerName.lowercased()]
        else {
            return nil
        }

        let providerRules = try Self.parseProviderRules(ref: providerRef)
        for providerRule in providerRules {
            guard self.matches(subject: subject, ruleType: providerRule.type, payload: providerRule.payload) else {
                continue
            }

            return LocalRuleSearchMatch(
                subject: subject,
                ruleIndex: index,
                policy: rule.policy,
                matchedRuleType: rule.type,
                matchedRulePayload: providerName,
                providerName: providerRef.name,
                providerPath: providerRef.displayPath,
                providerRuleType: providerRule.type,
                providerRulePayload: providerRule.payload)
        }

        return nil
    }

    private func matches(subject: RuleSearchSubject, ruleType: String, payload: String?) -> Bool {
        switch ruleType {
        case "MATCH":
            return true
        case "DOMAIN":
            guard subject.kind == .domain, let payload = payload?.trimmedNonEmpty else { return false }
            return subject.normalizedInput.caseInsensitiveCompare(payload.lowercased()) == .orderedSame
        case "DOMAIN-SUFFIX":
            guard subject.kind == .domain, let payload = payload?.trimmedNonEmpty else { return false }
            let candidate = payload.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard !candidate.isEmpty else { return false }
            return subject.normalizedInput == candidate
                || subject.normalizedInput.hasSuffix(".\(candidate)")
        case "DOMAIN-KEYWORD":
            guard subject.kind == .domain, let payload = payload?.trimmedNonEmpty?.lowercased(), !payload.isEmpty else {
                return false
            }
            return subject.normalizedInput.contains(payload)
        case "IP-CIDR", "IP-CIDR6":
            guard subject.kind == .ip,
                  let ipAddress = subject.ipAddress,
                  let payload = payload?.trimmedNonEmpty
            else {
                return false
            }
            return Self.ipAddress(ipAddress, matchesCIDR: payload)
        default:
            return false
        }
    }

    static func normalizeSubject(_ input: String) -> RuleSearchSubject? {
        let trimmed = input.trimmed
        guard !trimmed.isEmpty else { return nil }

        let candidate = Self.extractHostCandidate(from: trimmed)
        guard let normalizedCandidate = candidate.trimmedNonEmpty else { return nil }

        if let ipAddress = Self.parseIPAddress(normalizedCandidate) {
            return RuleSearchSubject(
                rawInput: trimmed,
                normalizedInput: normalizedCandidate,
                kind: .ip,
                ipAddress: ipAddress)
        }

        let normalizedDomain = normalizedCandidate
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard Self.isLikelyDomain(normalizedDomain) else { return nil }

        return RuleSearchSubject(
            rawInput: trimmed,
            normalizedInput: normalizedDomain,
            kind: .domain,
            ipAddress: nil)
    }

    private static func extractHostCandidate(from input: String) -> String {
        if input.contains("://"),
           let components = URLComponents(string: input),
           let host = components.host?.trimmedNonEmpty
        {
            return host
        }

        if input.hasPrefix("["),
           let closingBracketIndex = input.firstIndex(of: "]")
        {
            let hostStart = input.index(after: input.startIndex)
            return String(input[hostStart..<closingBracketIndex])
        }

        let withoutPath = input.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)
            ?? input

        if Self.parseIPAddress(withoutPath) != nil {
            return withoutPath
        }

        let colonCount = withoutPath.filter { $0 == ":" }.count
        if colonCount == 1,
           let lastColonIndex = withoutPath.lastIndex(of: ":")
        {
            let hostPart = String(withoutPath[..<lastColonIndex])
            let portPart = String(withoutPath[withoutPath.index(after: lastColonIndex)...])
            if portPart.allSatisfy(\.isNumber), !hostPart.isEmpty {
                return hostPart
            }
        }

        return withoutPath
    }

    private static func isLikelyDomain(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.count <= 253,
              !value.contains(" "),
              !value.contains(",")
        else {
            return false
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard value.unicodeScalars.allSatisfy(allowed.contains) else {
            return false
        }

        return value.contains(".") || value.hasSuffix("local")
    }

    private static func parseConfig(at configURL: URL, workingDirectoryURL: URL) throws -> ParsedRuleSearchConfig {
        let raw = try String(contentsOf: configURL, encoding: .utf8)
        let lines = raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        let providerRefs = Self.parseProviderRefs(lines: lines, workingDirectoryURL: workingDirectoryURL)
        let rules = Self.parseMainRules(lines: lines)
        return ParsedRuleSearchConfig(rules: rules, providerRefs: providerRefs)
    }

    private static func parseProviderRefs(
        lines: [String],
        workingDirectoryURL: URL) -> [String: ParsedRuleProviderRef]
    {
        var providerRefs: [String: ParsedRuleProviderRef] = [:]
        var insideSection = false
        var sectionIndent = 0
        var providerEntryIndent: Int?
        var currentName: String?
        var currentBlock: [String] = []

        func flushCurrentProvider() {
            guard let currentName else { return }
            let blockText = currentBlock.joined(separator: "\n")
            guard let pathValue = Self.extractProviderField("path", from: blockText)?.trimmedNonEmpty else {
                currentBlock.removeAll(keepingCapacity: true)
                return
            }

            let behaviorValue = Self.extractProviderField("behavior", from: blockText)?.lowercased() ?? "classical"
            let providerURL: URL
            if pathValue.hasPrefix("/") {
                providerURL = URL(fileURLWithPath: pathValue)
            } else {
                providerURL = workingDirectoryURL
                    .appendingPathComponent(pathValue, isDirectory: false)
                    .standardizedFileURL
            }

            providerRefs[currentName.lowercased()] = ParsedRuleProviderRef(
                name: currentName,
                behavior: ParsedRuleProviderBehavior(rawValue: behaviorValue) ?? .classical,
                fileURL: providerURL,
                displayPath: pathValue)
            currentBlock.removeAll(keepingCapacity: true)
        }

        for rawLine in lines {
            let sanitizedLine = Self.sanitizedYAMLLine(rawLine)
            let trimmed = sanitizedLine.trimmed
            if trimmed.isEmpty {
                if currentName != nil {
                    currentBlock.append(rawLine)
                }
                continue
            }

            let indent = Self.leadingWhitespaceCount(in: rawLine)

            if !insideSection {
                if trimmed == "rule-providers:" {
                    insideSection = true
                    sectionIndent = indent
                }
                continue
            }

            if indent <= sectionIndent {
                flushCurrentProvider()
                currentName = nil
                currentBlock.removeAll(keepingCapacity: true)
                insideSection = false
                providerEntryIndent = nil
                if trimmed == "rule-providers:" {
                    insideSection = true
                    sectionIndent = indent
                }
                continue
            }

            if let entryIndent = providerEntryIndent,
               indent == entryIndent,
               let providerName = Self.extractMappingKey(from: trimmed)
            {
                flushCurrentProvider()
                currentName = providerName
                currentBlock = [trimmed]
                continue
            }

            if providerEntryIndent == nil,
               let providerName = Self.extractMappingKey(from: trimmed)
            {
                providerEntryIndent = indent
                currentName = providerName
                currentBlock = [trimmed]
                continue
            }

            if currentName != nil {
                currentBlock.append(trimmed)
            }
        }

        flushCurrentProvider()
        return providerRefs
    }

    private static func parseMainRules(lines: [String]) -> [ParsedMainRule] {
        var rules: [ParsedMainRule] = []
        var insideSection = false
        var sectionIndent = 0

        for rawLine in lines {
            let sanitizedLine = Self.sanitizedYAMLLine(rawLine)
            let trimmed = sanitizedLine.trimmed
            if trimmed.isEmpty {
                continue
            }

            let indent = Self.leadingWhitespaceCount(in: rawLine)

            if !insideSection {
                if trimmed == "rules:" {
                    insideSection = true
                    sectionIndent = indent
                }
                continue
            }

            if indent <= sectionIndent {
                insideSection = false
                if trimmed == "rules:" {
                    insideSection = true
                    sectionIndent = indent
                }
                continue
            }

            guard let ruleText = Self.extractListItem(from: trimmed),
                  let rule = Self.parseMainRuleText(ruleText)
            else {
                continue
            }
            rules.append(rule)
        }

        return rules
    }

    private static func parseMainRuleText(_ ruleText: String) -> ParsedMainRule? {
        let parts = ruleText
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { Self.trimRuleValue(String($0)) }
        guard let first = parts.first?.uppercased(), !first.isEmpty else { return nil }

        switch first {
        case "MATCH":
            guard parts.count >= 2, let policy = parts[safe: 1]?.trimmedNonEmpty else { return nil }
            return ParsedMainRule(type: first, payload: nil, policy: policy)
        case "DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "IP-CIDR", "IP-CIDR6", "RULE-SET":
            guard parts.count >= 3,
                  let payload = parts[safe: 1]?.trimmedNonEmpty,
                  let policy = parts[safe: 2]?.trimmedNonEmpty
            else {
                return nil
            }
            return ParsedMainRule(type: first, payload: payload, policy: policy)
        default:
            return nil
        }
    }

    private static func parseProviderRules(ref: ParsedRuleProviderRef) throws -> [ParsedProviderRule] {
        let raw = try String(contentsOf: ref.fileURL, encoding: .utf8)
        let lines = raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        var rules: [ParsedProviderRule] = []
        var insidePayload = false
        var payloadIndent = 0

        for rawLine in lines {
            let sanitizedLine = Self.sanitizedYAMLLine(rawLine)
            let trimmed = sanitizedLine.trimmed
            if trimmed.isEmpty {
                continue
            }

            let indent = Self.leadingWhitespaceCount(in: rawLine)

            if !insidePayload {
                if trimmed == "payload:" {
                    insidePayload = true
                    payloadIndent = indent
                }
                continue
            }

            if indent <= payloadIndent {
                insidePayload = false
                continue
            }

            guard let payloadItem = Self.extractListItem(from: trimmed)?.trimmedNonEmpty else {
                continue
            }

            if let rule = Self.parseProviderRule(item: payloadItem, behavior: ref.behavior) {
                rules.append(rule)
            }
        }

        return rules
    }

    private static func parseProviderRule(
        item: String,
        behavior: ParsedRuleProviderBehavior) -> ParsedProviderRule?
    {
        switch behavior {
        case .classical:
            let parts = item
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { Self.trimRuleValue(String($0)) }
            guard let type = parts.first?.uppercased(), !type.isEmpty else { return nil }
            switch type {
            case "DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "IP-CIDR", "IP-CIDR6":
                guard let payload = parts[safe: 1]?.trimmedNonEmpty else { return nil }
                return ParsedProviderRule(type: type, payload: payload)
            case "MATCH":
                return ParsedProviderRule(type: type, payload: nil)
            default:
                return nil
            }
        case .domain:
            let normalized = Self.trimRuleValue(item)
            guard let payload = normalized.trimmedNonEmpty else { return nil }
            if payload.hasPrefix("+.") || payload.hasPrefix("*.") || payload.hasPrefix(".") {
                return ParsedProviderRule(
                    type: "DOMAIN-SUFFIX",
                    payload: String(payload.drop { $0 == "+" || $0 == "*" || $0 == "." }))
            }
            return ParsedProviderRule(type: "DOMAIN", payload: payload)
        case .ipcidr:
            guard let payload = Self.trimRuleValue(item).trimmedNonEmpty else { return nil }
            return ParsedProviderRule(type: "IP-CIDR", payload: payload)
        }
    }

    private static func extractProviderField(_ field: String, from blockText: String) -> String? {
        let escapedField = NSRegularExpression.escapedPattern(for: field)
        let pattern = #"(?m)(?:^|[,{]\s*)\#(escapedField)\s*:\s*("[^"]*"|'[^']*'|[^,\n}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(blockText.startIndex..<blockText.endIndex, in: blockText)
        guard let match = regex.firstMatch(in: blockText, range: range),
              let valueRange = Range(match.range(at: 1), in: blockText)
        else {
            return nil
        }
        return Self.trimRuleValue(String(blockText[valueRange]))
    }

    private static func extractMappingKey(from trimmedLine: String) -> String? {
        guard !trimmedLine.hasPrefix("-"),
              let colonIndex = trimmedLine.firstIndex(of: ":")
        else {
            return nil
        }

        let key = trimmedLine[..<colonIndex].trimmed
        guard !key.isEmpty else { return nil }
        return Self.trimRuleValue(key)
    }

    private static func extractListItem(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("- ") else { return nil }
        return String(trimmedLine.dropFirst(2))
    }

    private static func trimRuleValue(_ raw: String) -> String {
        var value = raw.trimmed
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        return value.trimmed
    }

    private static func sanitizedYAMLLine(_ line: String) -> String {
        var result = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for character in line {
            if escaped {
                result.append(character)
                escaped = false
                continue
            }

            if character == "\\", inDoubleQuote {
                result.append(character)
                escaped = true
                continue
            }

            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
                result.append(character)
                continue
            }

            if character == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
                result.append(character)
                continue
            }

            if character == "#", !inSingleQuote, !inDoubleQuote {
                break
            }

            result.append(character)
        }

        return result
    }

    private static func leadingWhitespaceCount(in line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.count
    }

    private static func parseIPAddress(_ value: String) -> IPAddressBytes? {
        var ipv4 = in_addr()
        if value.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            return IPAddressBytes(family: AF_INET, bytes: withUnsafeBytes(of: ipv4) { Array($0) })
        }

        var ipv6 = in6_addr()
        if value.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
            return IPAddressBytes(family: AF_INET6, bytes: withUnsafeBytes(of: ipv6) { Array($0) })
        }

        return nil
    }

    private static func ipAddress(_ address: IPAddressBytes, matchesCIDR cidr: String) -> Bool {
        let parts = cidr.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let baseAddress = Self.parseIPAddress(String(parts[0]).trimmed),
              let prefixLength = Int(String(parts[1]).trimmed),
              baseAddress.family == address.family
        else {
            return false
        }

        let maxPrefixLength = address.bytes.count * 8
        guard (0...maxPrefixLength).contains(prefixLength) else { return false }

        let fullBytes = prefixLength / 8
        let remainingBits = prefixLength % 8

        if fullBytes > 0 {
            for index in 0..<fullBytes where address.bytes[index] != baseAddress.bytes[index] {
                return false
            }
        }

        guard remainingBits > 0 else { return true }
        let mask = UInt8(0xFF << (8 - remainingBits))
        return (address.bytes[fullBytes] & mask) == (baseAddress.bytes[fullBytes] & mask)
    }
}

private struct ParsedRuleSearchConfig {
    let rules: [ParsedMainRule]
    let providerRefs: [String: ParsedRuleProviderRef]
}

private struct ParsedMainRule {
    let type: String
    let payload: String?
    let policy: String
}

private struct ParsedProviderRule {
    let type: String
    let payload: String?
}

private struct ParsedRuleProviderRef {
    let name: String
    let behavior: ParsedRuleProviderBehavior
    let fileURL: URL
    let displayPath: String
}

private enum ParsedRuleProviderBehavior: String {
    case classical
    case domain
    case ipcidr
}

struct IPAddressBytes: Equatable, Sendable {
    let family: Int32
    let bytes: [UInt8]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
