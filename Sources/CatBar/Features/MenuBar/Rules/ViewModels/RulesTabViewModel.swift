import Foundation
import SwiftUI

@MainActor
final class RulesTabViewModel: ObservableObject {
    private let presentRulesUseCase: PresentRulesUseCase
    private let matchLocalRuleUseCase: MatchLocalRuleUseCase

    @Published private(set) var policyGroups: [RulePolicyGroup] = []
    @Published private(set) var providerLookup: [String: ProviderDetail] = [:]
    @Published var searchText: String = ""
    @Published private(set) var searchState: RuleSearchPresentationState = .idle

    init(
        presentRulesUseCase: PresentRulesUseCase = PresentRulesUseCase(),
        matchLocalRuleUseCase: MatchLocalRuleUseCase = MatchLocalRuleUseCase())
    {
        self.presentRulesUseCase = presentRulesUseCase
        self.matchLocalRuleUseCase = matchLocalRuleUseCase
    }

    func updateVisibleRules(items: [RuleItem], providers: [String: ProviderDetail]) {
        let output = self.presentRulesUseCase.execute(items: items, providers: providers)
        let nextGroups = output.groups
        let nextLookup = output.providerLookup

        if nextGroups != self.policyGroups {
            self.policyGroups = nextGroups
        }

        guard nextLookup != self.providerLookup else { return }
        self.providerLookup = nextLookup
    }

    func clearSearch() {
        self.searchText = ""
        self.searchState = .idle
    }

    func clearSearchResult() {
        self.searchState = .idle
    }

    func resetSearchAvailability(isLocalTarget: Bool) {
        guard !isLocalTarget else { return }
        self.searchState = .idle
    }

    func searchCurrentLocalRules(configPath: String?) async {
        let trimmedQuery = self.searchText.trimmed
        guard !trimmedQuery.isEmpty else {
            self.searchState = .idle
            return
        }

        self.searchState = .searching
        let useCase = self.matchLocalRuleUseCase

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try useCase.execute(input: trimmedQuery, configPath: configPath)
            }.value

            if let result {
                self.searchState = .matched(result)
            } else if let subject = MatchLocalRuleUseCase.normalizeSubject(trimmedQuery) {
                self.searchState = .noMatch(subject)
            } else {
                self.searchState = .invalidInput
            }
        } catch let error as LocalRuleSearchError {
            switch error {
            case .invalidInput:
                self.searchState = .invalidInput
            case .missingConfig:
                self.searchState = .missingConfig
            }
        } catch {
            self.searchState = .failed(error.localizedDescription)
        }
    }

}
