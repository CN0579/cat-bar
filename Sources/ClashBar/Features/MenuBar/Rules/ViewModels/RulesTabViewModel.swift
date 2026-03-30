import Foundation
import SwiftUI

struct RulesGroup: Identifiable, Equatable {
    let name: String
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
        let nextGroups = Self.buildRuleGroups(from: nextRules)
        guard nextGroups != self.ruleGroups else { return }
        self.ruleGroups = nextGroups
    }

    private static func buildRuleGroups(from rules: [RuleItem]) -> [RulesGroup] {
        var dict: [String: [RuleItem]] = [:]
        var order: [String] = []
        for rule in rules {
            let key = rule.proxy?.trimmedNonEmpty ?? "Unknown"
            if dict[key] == nil {
                order.append(key)
            }
            dict[key, default: []].append(rule)
        }
        return order.map { RulesGroup(name: $0, rules: dict[$0] ?? []) }
    }
}
