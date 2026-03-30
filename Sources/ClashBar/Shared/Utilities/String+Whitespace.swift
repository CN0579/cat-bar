import Foundation

extension StringProtocol {
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var nonEmpty: String? {
        self.isEmpty ? nil : self
    }

    var trimmedNonEmpty: String? {
        self.trimmed.nonEmpty
    }

    static func clashRuleTypeDisplayText(from raw: String?) -> String? {
        guard let raw = raw.trimmedNonEmpty else { return nil }

        let normalized = raw.replacingOccurrences(of: "_", with: "-")
        let kebab = normalized.contains("-") ? normalized : self.hyphenatedRuleType(normalized)
        let formatted = self.normalizeRuleTypeTokens(kebab.uppercased())

        return formatted.nonEmpty
    }

    private static func hyphenatedRuleType(_ raw: String) -> String {
        let characters = Array(raw)
        var result = ""

        for (index, character) in characters.enumerated() {
            let current = String(character).unicodeScalars.first
            let previous = index > 0 ? String(characters[index - 1]).unicodeScalars.first : nil
            let next = index + 1 < characters.count ? String(characters[index + 1]).unicodeScalars.first : nil

            let isUppercase = current.map(CharacterSet.uppercaseLetters.contains) ?? false
            let isLowercase = current.map(CharacterSet.lowercaseLetters.contains) ?? false
            let isDigit = current.map(CharacterSet.decimalDigits.contains) ?? false
            let previousIsUppercase = previous.map(CharacterSet.uppercaseLetters.contains) ?? false
            let previousIsLowercase = previous.map(CharacterSet.lowercaseLetters.contains) ?? false
            let previousIsDigit = previous.map(CharacterSet.decimalDigits.contains) ?? false
            let nextIsLowercase = next.map(CharacterSet.lowercaseLetters.contains) ?? false

            if index > 0 {
                if isUppercase, (previousIsLowercase || previousIsDigit) {
                    result.append("-")
                } else if isUppercase, previousIsUppercase, nextIsLowercase {
                    result.append("-")
                } else if isDigit, !(previousIsDigit || characters[index - 1] == "-") {
                    result.append("-")
                }
            }

            if isLowercase || isUppercase || isDigit || character == "-" {
                result.append(character)
            } else {
                result.append("-")
            }
        }

        return result
    }

    private static func normalizeRuleTypeTokens(_ value: String) -> String {
        var normalized = value
        let replacements = [
            ("RULESET", "RULE-SET"),
            ("SUBRULE", "SUB-RULE"),
            ("DOMAINSUFFIX", "DOMAIN-SUFFIX"),
            ("DOMAINKEYWORD", "DOMAIN-KEYWORD"),
            ("DOMAINREGEX", "DOMAIN-REGEX"),
            ("PROCESSPATHREGEX", "PROCESS-PATH-REGEX"),
            ("PROCESSNAMEREGEX", "PROCESS-NAME-REGEX"),
            ("PROCESSPATH", "PROCESS-PATH"),
            ("PROCESSNAME", "PROCESS-NAME"),
            ("SRCIPCIDR", "SRC-IP-CIDR"),
            ("DSTIPCIDR", "DST-IP-CIDR"),
            ("IPCIDR6", "IP-CIDR6"),
            ("IPCIDR", "IP-CIDR"),
            ("IPASN", "IP-ASN"),
            ("SRCPORT", "SRC-PORT"),
            ("DSTPORT", "DST-PORT"),
            ("INPORT", "IN-PORT"),
            ("INTYPE", "IN-TYPE"),
        ]

        for (source, target) in replacements {
            normalized = normalized.replacingOccurrences(of: source, with: target)
        }

        while normalized.contains("--") {
            normalized = normalized.replacingOccurrences(of: "--", with: "-")
        }

        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

extension String? {
    var trimmedOrEmpty: String {
        self?.trimmed ?? ""
    }

    var trimmedNonEmpty: String? {
        self.flatMap(\.trimmedNonEmpty)
    }
}
