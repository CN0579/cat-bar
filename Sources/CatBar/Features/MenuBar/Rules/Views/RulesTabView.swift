import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

private struct RuleProviderStats {
    let count: Int
    let updatedText: String?
}

extension MenuBarRootView {
    var rulesTabBody: some View {
        let groups = self.rulesViewModel.policyGroups
        let providerLookup = self.rulesViewModel.providerLookup
        let providerStats = self.makeRuleProviderStatsLookup(providerLookup: providerLookup)
        let groupConcreteCounts = self.makeRuleGroupConcreteCounts(groups: groups, providerStats: providerStats)
        let totalConcreteCount = groupConcreteCounts.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                self.rulesStatChip(title: tr("ui.rule.stats.rules"), value: "\(totalConcreteCount)")

                Spacer(minLength: 0)
                self.rulesRefreshButton
            }
            .padding(.vertical, T.space6)

            if groups.isEmpty {
                Text(tr("ui.empty.rules"))
                    .font(.app(size: T.FontSize.body, weight: .regular))
                    .foregroundStyle(nativeSecondaryLabel)
                    .padding(.horizontal, T.space4)
                    .padding(.vertical, T.space8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        self.rulePolicyGroupSection(
                            group: group,
                            providerStats: providerStats,
                            concreteCount: groupConcreteCounts[group.id] ?? group.rules.count)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func rulePolicyGroupSection(
        group: RulePolicyGroup,
        providerStats: [String: RuleProviderStats],
        concreteCount: Int) -> some View
    {
        let isExpanded = expandedRuleGroups.contains(group.policy)
        let policyText = group.policy.isEmpty ? tr("ui.common.na") : group.policy
        let hovered = hoveredRuleGroup == group.policy

        return VStack(spacing: 0) {
            Button {
                if isExpanded {
                    expandedRuleGroups.remove(group.policy)
                } else {
                    expandedRuleGroups.insert(group.policy)
                }
            } label: {
                HStack(spacing: T.space4) {
                    Image(systemName: "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 14, alignment: .center)

                    Text(policyText)
                        .font(.app(size: T.FontSize.body, weight: .semibold))
                        .foregroundStyle(nativePrimaryLabel)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(concreteCount)")
                        .font(.app(size: T.FontSize.caption, weight: .bold))
                        .foregroundStyle(nativeSecondaryLabel)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.horizontal, T.space4)
                .frame(height: T.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(nativeHoverRowBackground(hovered))
            .onHover { hoveredRuleGroup = self.nextHovered(
                current: hoveredRuleGroup, target: group.policy, isHovering: $0) }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.rules) { rule in
                        self.rulesRow(rule: rule, providerStats: providerStats)
                    }
                }
            }
        }
    }

    func rulesStatChip(title: String, value: String) -> some View {
        HStack(spacing: T.space4) {
            Text(title.uppercased())
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
            Text(value)
                .font(.app(size: T.FontSize.body, weight: .bold))
                .foregroundStyle(nativePrimaryLabel)
        }
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space2)
    }

    var rulesRefreshButton: some View {
        self.compactTopIcon(
            "arrow.clockwise",
            label: tr("ui.action.refresh"),
            toneOverride: nativeInfo,
            isLoading: appSession.isRuleProvidersRefreshing)
        {
            await appSession.refreshRuleProviders()
        }
        .help(tr("ui.action.refresh"))
        .opacity(appSession.isRuleProvidersRefreshing ? 0.6 : 1)
    }

    fileprivate func rulesRow(rule: RuleItem, providerStats: [String: RuleProviderStats]) -> some View {
        let typeText = (rule.type.trimmedNonEmpty ?? tr("ui.common.na")).uppercased()
        let targetText = rule.payload.trimmedNonEmpty ?? tr("ui.common.na")
        let stats = self.ruleStats(payload: targetText, providerStats: providerStats)

        return HStack(spacing: T.space4) {
            Color.clear.frame(width: 14)

            Text(targetText)
                .font(.app(size: T.FontSize.body, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(typeText)
                .font(.app(size: T.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeTertiaryLabel)
                .frame(width: 80, alignment: .leading)

            Text(stats.updatedText ?? "")
                .font(.app(size: T.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeTertiaryLabel)
                .lineLimit(1)
                .frame(width: 36, alignment: .trailing)

            Text(stats.hasProvider ? "\(stats.count)" : "")
                .font(.app(size: T.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeSecondaryLabel)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, T.space4)
        .frame(height: T.rowHeight)
    }

    fileprivate func ruleStats(
        payload: String,
        providerStats: [String: RuleProviderStats]) -> (count: Int, updatedText: String?, hasProvider: Bool)
    {
        let payloadTrimmed = payload.trimmed
        guard !payloadTrimmed.isEmpty, payloadTrimmed != tr("ui.common.na") else {
            return (count: 0, updatedText: nil, hasProvider: false)
        }

        if let provider = providerStats[payloadTrimmed.lowercased()] {
            return (
                count: provider.count,
                updatedText: provider.updatedText,
                hasProvider: true)
        }
        return (count: 0, updatedText: nil, hasProvider: false)
    }

    private func makeRuleProviderStatsLookup(
        providerLookup: [String: ProviderDetail]) -> [String: RuleProviderStats]
    {
        guard !providerLookup.isEmpty else { return [:] }

        var stats: [String: RuleProviderStats] = [:]
        stats.reserveCapacity(providerLookup.count)

        for (key, provider) in providerLookup {
            stats[key] = RuleProviderStats(
                count: max(0, provider.ruleCount ?? 0),
                updatedText: ValueFormatter.relativeTime(from: provider.updatedAt, language: language))
        }

        return stats
    }

    private func makeRuleGroupConcreteCounts(
        groups: [RulePolicyGroup],
        providerStats: [String: RuleProviderStats]) -> [String: Int]
    {
        guard !groups.isEmpty else { return [:] }

        var counts: [String: Int] = [:]
        counts.reserveCapacity(groups.count)

        for group in groups {
            var count = 0
            for rule in group.rules {
                let payload = rule.payload?.trimmed ?? ""
                if let stats = providerStats[payload.lowercased()], stats.count > 0 {
                    count += stats.count
                } else {
                    count += 1
                }
            }
            counts[group.id] = count
        }

        return counts
    }

    func refreshVisibleRules() {
        self.rulesViewModel.updateVisibleRules(
            items: self.appSession.ruleItems,
            providers: self.appSession.ruleProviders)
    }
}
