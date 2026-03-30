import Foundation
import SwiftUI

struct RulesGroup: Identifiable, Equatable {
    let name: String
    let totalRuleCount: Int
    let ruleProviderNames: [String]
    let rules: [RuleItem]
    var id: String { self.name }
}

@MainActor
final class RulesTabViewModel: ObservableObject {
    private let presentRulesUseCase: PresentRulesUseCase

    @Published private(set) var ruleGroups: [RulesGroup] = []
    @Published var expandedGroupNames: Set<String> = []

    init(presentRulesUseCase: PresentRulesUseCase = PresentRulesUseCase()) {
        self.presentRulesUseCase = presentRulesUseCase
    }

    func toggleGroupExpansion(_ name: String) {
        if self.expandedGroupNames.contains(name) {
            self.expandedGroupNames.remove(name)
        } else {
            self.expandedGroupNames.insert(name)
        }
    }

    func updateVisibleRules(items: [RuleItem], providers: [String: ProviderDetail]) {
        let nextRules = self.presentRulesUseCase.execute(items: items, providers: providers)
        let nextGroups = Self.buildRuleGroups(from: nextRules, providers: providers)
        guard nextGroups != self.ruleGroups else { return }
        self.ruleGroups = nextGroups
    }

    private static func buildRuleGroups(from rules: [RuleItem], providers: [String: ProviderDetail]) -> [RulesGroup] {
        var groupedRules: [String: [RuleItem]] = [:]
        var order: [String] = []
        for rule in rules {
            let key = rule.proxy?.trimmedNonEmpty ?? "Unknown"
            if groupedRules[key] == nil {
                order.append(key)
            }
            groupedRules[key, default: []].append(rule)
        }

        return order.map { groupName in
            let groupRules = groupedRules[groupName] ?? []
            var totalRuleCount = 0
            var seenProviderNames = Set<String>()
            var ruleProviderNames: [String] = []

            for rule in groupRules {
                if let providerName = Self.ruleProviderName(for: rule),
                   let provider = providers[providerName]
                {
                    if seenProviderNames.insert(providerName).inserted {
                        ruleProviderNames.append(providerName)
                        totalRuleCount += provider.ruleCount ?? 0
                    }
                } else {
                    totalRuleCount += 1
                }
            }

            return RulesGroup(
                name: groupName,
                totalRuleCount: totalRuleCount,
                ruleProviderNames: ruleProviderNames,
                rules: groupRules)
        }
    }

    private static func ruleProviderName(for rule: RuleItem) -> String? {
        let payload = rule.payload?.trimmedNonEmpty
        let lowerType = rule.type?.lowercased() ?? ""

        if lowerType.contains("ruleset") || lowerType.contains("rule-set") {
            return payload
        }

        return nil
    }
}
