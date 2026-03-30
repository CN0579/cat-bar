import Foundation

struct PresentRulesUseCase {
    func execute(items: [RuleItem], providers _: [String: ProviderDetail]) -> [RuleItem] {
        Array(items.prefix(100))
    }
}
