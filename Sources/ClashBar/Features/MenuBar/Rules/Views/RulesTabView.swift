import SwiftUI

extension MenuBarRootView {
    func rulesTabBody(isMeasuring: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            self.rulesTabPinnedHeader()
            self.rulesTabScrollableList(isMeasuring: isMeasuring)
        }
    }

    func rulesTabPinnedHeader() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: MenuBarLayoutTokens.space8) {
                    self.rulesStatChip(title: tr("ui.rule.stats.rules"), value: "\(appSession.rulesCount)")
                    self.rulesStatChip(title: tr("ui.rule.stats.sets"), value: "\(appSession.providerRuleCount)")
                }

                Spacer(minLength: 0)
                self.rulesRefreshButton
            }
            .padding(.horizontal, MenuBarLayoutTokens.space4)
            .padding(.vertical, MenuBarLayoutTokens.space6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(nativeSeparator)
                    .frame(height: MenuBarLayoutTokens.stroke)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: 24)
                Text(tr("ui.rules.column.target_type"))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
                    .frame(width: 120, alignment: .leading)
                    .padding(.trailing, MenuBarLayoutTokens.space6)
                Text(tr("ui.rules.column.policy"))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
                    .padding(.leading, MenuBarLayoutTokens.space6)
                    .frame(width: 90, alignment: .leading)
                Text(tr("ui.rules.column.stats"))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .foregroundStyle(nativeTertiaryLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .textCase(.uppercase)
            .padding(.horizontal, MenuBarLayoutTokens.space4)
            .padding(.vertical, MenuBarLayoutTokens.space6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(nativeSeparator)
                    .frame(height: MenuBarLayoutTokens.stroke)
            }
        }
    }

    func rulesTabScrollableList(isMeasuring: Bool = false) -> some View {
        let visibleRules = self.rulesViewModel.visibleRules
        let providerLookup = self.rulesViewModel.providerLookup

        return Group {
            if visibleRules.isEmpty {
                Text(tr("ui.empty.rules"))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
                    .foregroundStyle(nativeSecondaryLabel)
                    .padding(.horizontal, MenuBarLayoutTokens.space4)
                    .padding(.vertical, MenuBarLayoutTokens.space8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                let displayRules = isMeasuring ? Array(visibleRules.prefix(25)) : visibleRules
                self.rulesListVStack(rows: displayRules, providerLookup: providerLookup)
            }
        }
    }

    /// Plain `VStack` + dividers (no `LazyVStack` / `SeparatedForEach`) so scroll layout stays tight in SwiftUI `ScrollView`.
    @ViewBuilder
    private func rulesListVStack(rows: [RuleItem], providerLookup: [String: ProviderDetail]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.rowID) { index, rule in
                self.ruleRowByItem(rule: rule, providerLookup: providerLookup)
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(self.nativeSeparator)
                        .frame(height: MenuBarLayoutTokens.stroke)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    func rulesStatChip(title: String, value: String) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Text(title.uppercased())
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
            Text(value)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .bold))
                .foregroundStyle(nativePrimaryLabel)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space2)
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

    func ruleRowByItem(rule: RuleItem, providerLookup: [String: ProviderDetail]) -> some View {
        let hovered = hoveredRuleID == rule.rowID
        return RulesListRowView(
            rule: rule,
            providerLookup: providerLookup,
            language: language,
            showsBottomDivider: false)
            .equatable()
            .background(nativeHoverRowBackground(hovered))
            .onHover { hoveredRuleID = self.nextHovered(
                current: hoveredRuleID, target: rule.rowID, isHovering: $0) }
    }

    func refreshVisibleRules() {
        self.rulesViewModel.updateVisibleRules(
            items: self.appSession.ruleItems,
            providers: self.appSession.ruleProviders)
    }
}
