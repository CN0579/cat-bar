import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRootView {
    func rulesTabBody(isMeasuring _: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: T.space6) {
            self.rulesTabPinnedHeader()
            self.rulesTabScrollableList()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    func rulesTabScrollableList() -> some View {
        MeasurementAwareVStack(alignment: .leading, spacing: T.space6, usesLazyStack: false) {
            if self.rulesViewModel.ruleGroups.isEmpty {
                self.emptyCard(tr("ui.empty.rules"))
            } else {
                self.ruleGroupSections()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, T.space8)
    }

    func rulesTabPinnedHeader() -> some View {
        HStack(spacing: 0) {
            HStack(spacing: T.space8) {
                self.rulesStatChip(title: tr("ui.rule.stats.rules"), value: "\(appSession.rulesCount)")
                self.rulesStatChip(title: tr("ui.rule.stats.sets"), value: "\(appSession.providerRuleCount)")
            }

            Spacer(minLength: 0)
            self.rulesRefreshButton
        }
        .padding(.horizontal, T.space4)
        .padding(.vertical, T.space6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(nativeSeparator)
                .frame(height: T.stroke)
        }
    }

    private func ruleGroupSections() -> some View {
        let groups = self.rulesViewModel.ruleGroups

        return MeasurementAwareVStack(alignment: .leading, spacing: T.space4, usesLazyStack: false) {
            ForEach(groups) { group in
                self.ruleGroupCard(group: group)
            }
        }
    }

    private func ruleGroupCard(group: RulesGroup) -> some View {
        let isExpanded = rulesViewModel.expandedGroupNames.contains(group.name)
        let isUpdating = group.ruleProviderNames.contains { self.appSession.ruleProviderUpdating.contains($0) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: T.space4) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        rulesViewModel.toggleGroupExpansion(group.name)
                    }
                } label: {
                    HStack(spacing: T.space6) {
                        Text(group.name)
                            .font(.app(size: T.FontSize.body, weight: .semibold))
                            .foregroundStyle(nativePrimaryLabel)
                            .lineLimit(1)

                        Text("\(group.totalRuleCount)")
                            .font(.app(size: T.FontSize.caption, weight: .semibold))
                            .foregroundStyle(nativeSecondaryLabel)
                            .padding(.horizontal, T.space4)
                            .padding(.vertical, T.space1)
                            .background(nativeBadgeCapsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !group.ruleProviderNames.isEmpty {
                    self.providerActionButton(.refresh, isLoading: isUpdating) {
                        await self.appSession.updateRuleProviders(
                            names: group.ruleProviderNames,
                            actionName: tr("log.action_name.update_rule_group_providers", group.name))
                    }
                    .frame(width: T.rowLeadingIcon, alignment: .center)
                    .help(tr("ui.action.refresh"))
                }

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        rulesViewModel.toggleGroupExpansion(group.name)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                        .frame(width: T.rowLeadingIcon, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, T.space4)
            .padding(.vertical, T.space6)

            if isExpanded { self.ruleGroupExpandedContent(group: group) }
        }
        .background(
            RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                .fill(nativeControlFill.opacity(isDarkAppearance ? 0.24 : 0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                        .stroke(nativeControlBorder.opacity(isDarkAppearance ? 0.34 : 0.10),
                                lineWidth: T.stroke)
                })
    }

    private func ruleGroupExpandedContent(group: RulesGroup) -> some View {
        let displayRules = group.rules

        return VStack(spacing: 0) {
            Divider()
                .overlay(nativeSeparator)
                .padding(.horizontal, T.space4)

            if displayRules.isEmpty {
                Text(tr("ui.common.na"))
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativeSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, T.space6)
                    .padding(.vertical, T.space4)
            } else {
                MeasurementAwareVStack(alignment: .leading, spacing: 0, usesLazyStack: false) {
                    ForEach(displayRules) { rule in
                        self.ruleRow(rule: rule)
                    }
                }
                .padding(.vertical, T.space2)
            }
        }
    }

    private func ruleRow(rule: RuleItem) -> some View {
        let typeText = String.clashRuleTypeDisplayText(from: rule.type) ?? tr("ui.common.na")
        let targetText = rule.payload.trimmedNonEmpty ?? tr("ui.common.na")
        let iconSpec = self.ruleTypeIconSpec(for: typeText)
        let ruleProviderName = self.ruleProviderName(for: rule)
        let ruleProviderDetail = ruleProviderName.flatMap { self.appSession.ruleProviders[$0] }
        let isUpdating = ruleProviderName.map { self.appSession.ruleProviderUpdating.contains($0) } ?? false

        return HStack(spacing: T.space4) {

            Text(targetText)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if let ruleCount = ruleProviderDetail?.ruleCount {
                Text("\(ruleCount)")
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(nativeSecondaryLabel)
                    .padding(.horizontal, T.space4)
                    .padding(.vertical, T.space1)
                    .background(nativeBadgeCapsule())
            }

            Text(typeText)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(nativeTertiaryLabel)
                .lineLimit(1)
                .padding(.horizontal, T.space4)
                .padding(.vertical, T.space1)
                .background(
                    RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.1)))

            if let ruleProviderName {
                self.providerActionButton(.refresh, isLoading: isUpdating) {
                    await self.appSession.updateRuleProvider(name: ruleProviderName)
                }
                .frame(width: T.rowLeadingIcon, alignment: .center)
                .help(tr("ui.action.refresh"))
            }
        }
        .frame(minHeight: T.compactRowHeight, alignment: .center)
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space1)
    }

    private func ruleProviderName(for rule: RuleItem) -> String? {
        let lowerType = rule.type?.lowercased() ?? ""
        guard lowerType.contains("ruleset") || lowerType.contains("rule-set") else {
            return nil
        }

        guard let payload = rule.payload?.trimmedNonEmpty,
              self.appSession.ruleProviders[payload] != nil
        else {
            return nil
        }
        return payload
    }

    private func ruleTypeIconSpec(for type: String) -> (symbol: String, color: Color) {
        let lower = type.lowercased()
        if lower.contains("ipcidr") || lower.contains("ip-cidr") {
            return ("globe.americas.fill", nativeInfo.opacity(T.Opacity.solid))
        }
        if lower.contains("domain") || lower.contains("suffix") || lower.contains("keyword") {
            return ("network", nativeTeal.opacity(T.Opacity.solid))
        }
        if lower.contains("ruleset") || lower.contains("rule-set") {
            return ("list.bullet.rectangle.fill", nativeWarning.opacity(T.Opacity.solid))
        }
        return ("circle.grid.2x2.fill", nativeIndigo.opacity(T.Opacity.solid))
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
            "arrow.triangle.2.circlepath",
            label: tr("ui.action.refresh"),
            toneOverride: nativeInfo,
            isLoading: appSession.isRuleProvidersRefreshing)
        {
            await appSession.refreshRuleProviders()
        }
        .help(tr("ui.action.refresh"))
        .opacity(appSession.isRuleProvidersRefreshing ? 0.6 : 1)
    }

    func refreshVisibleRules() {
        self.rulesViewModel.updateVisibleRules(
            items: self.appSession.ruleItems,
            providers: self.appSession.ruleProviders)
    }
}
