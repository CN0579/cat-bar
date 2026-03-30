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

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    rulesViewModel.toggleGroupExpansion(group.name)
                }
            } label: {
                HStack(spacing: T.space6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeInfo.opacity(T.Opacity.solid))
                        .frame(width: T.rowLeadingIcon, height: T.rowLeadingIcon)

                    Text(group.name)
                        .font(.app(size: T.FontSize.body, weight: .semibold))
                        .foregroundStyle(nativePrimaryLabel)
                        .lineLimit(1)

                    Text("\(group.rules.count)")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeSecondaryLabel)
                        .padding(.horizontal, T.space4)
                        .padding(.vertical, T.space1)
                        .background(nativeBadgeCapsule())

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                        .frame(width: T.space8, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, T.space4)
                .padding(.vertical, T.space6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
        let typeText = self.formattedRuleTypeText(rule.type)
        let targetText = rule.payload.trimmedNonEmpty ?? tr("ui.common.na")
        let iconSpec = self.ruleTypeIconSpec(for: typeText)

        return HStack(spacing: T.space4) {
            Image(systemName: iconSpec.symbol)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(iconSpec.color)
                .frame(width: T.rowLeadingIcon, alignment: .center)

            Text(targetText)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Text(typeText)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(nativeTertiaryLabel)
                .lineLimit(1)
                .padding(.horizontal, T.space4)
                .padding(.vertical, T.space1)
                .background(
                    RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.1)))
        }
        .frame(minHeight: T.compactRowHeight, alignment: .center)
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space1)
    }

    private func formattedRuleTypeText(_ raw: String?) -> String {
        guard let raw = raw.trimmedNonEmpty else { return tr("ui.common.na") }

        let normalized = raw.replacingOccurrences(of: "_", with: "-")
        let kebab = normalized.contains("-") ? normalized : self.hyphenatedRuleType(normalized)

        return self.normalizeRuleTypeTokens(kebab.uppercased())
    }

    private func hyphenatedRuleType(_ raw: String) -> String {
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

    private func normalizeRuleTypeTokens(_ value: String) -> String {
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

    func refreshVisibleRules() {
        self.rulesViewModel.updateVisibleRules(
            items: self.appSession.ruleItems,
            providers: self.appSession.ruleProviders)
    }
}
