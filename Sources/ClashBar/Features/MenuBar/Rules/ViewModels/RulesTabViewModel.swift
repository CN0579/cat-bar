import Foundation
import SwiftUI

struct RuleGroup: Identifiable, Equatable {
    let name: String
    let rules: [RuleItem]
    var id: String { self.name }
}

@MainActor
final class RulesTabViewModel: ObservableObject {
    private let presentRulesUseCase: PresentRulesUseCase

    @Published private(set) var groupedRules: [RuleGroup] = []
    @Published var expandedRuleGroups: Set<String> = []

    init(presentRulesUseCase: PresentRulesUseCase = PresentRulesUseCase()) {
        self.presentRulesUseCase = presentRulesUseCase
    }

    func toggleRuleGroup(_ name: String) {
        if self.expandedRuleGroups.contains(name) {
            self.expandedRuleGroups.remove(name)
        } else {
            self.expandedRuleGroups.insert(name)
        }
    }

    func updateVisibleRules(items: [RuleItem], providers: [String: ProviderDetail]) {
        let nextRules = self.presentRulesUseCase.execute(items: items, providers: providers)
        let nextGroups = Self.buildGroupedRules(from: nextRules)
        guard nextGroups != self.groupedRules else { return }
        self.groupedRules = nextGroups
    }

    private static func buildGroupedRules(from rules: [RuleItem]) -> [RuleGroup] {
        var dict: [String: [RuleItem]] = [:]
        var order: [String] = []
        for rule in rules {
            let key = rule.proxy?.trimmedNonEmpty ?? "Unknown"
            if dict[key] == nil {
                order.append(key)
            }
            dict[key, default: []].append(rule)
        }
        return order.map { RuleGroup(name: $0, rules: dict[$0] ?? []) }
    }
}
