import AppKit
import SwiftUI

// MARK: - SwiftUI row (shared with `MenuBarRootView.ruleRowByItem`)

struct RulesListRowView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let rule: RuleItem
    let providerLookup: [String: ProviderDetail]
    let language: AppLanguage
    /// `NSTableView` rows draw their own hairline; SwiftUI lists use `SeparatedForEach` dividers.
    var showsBottomDivider: Bool

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rule == rhs.rule &&
        lhs.providerLookup == rhs.providerLookup &&
        lhs.language == rhs.language &&
        lhs.showsBottomDivider == rhs.showsBottomDivider
    }

    var body: some View {
        let typeText = (rule.type.trimmedNonEmpty ?? tr("ui.common.na")).uppercased()
        let targetText = rule.payload.trimmedNonEmpty ?? tr("ui.common.na")
        let policyText = rule.proxy.trimmedNonEmpty ?? tr("ui.common.na")
        let iconSpec = self.ruleTypeIcon(for: typeText)
        let badge = self.rulePolicyBadge(for: policyText)
        let stats = self.ruleStats(payload: targetText)

        HStack(spacing: 0) {
            Image(systemName: iconSpec.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.subhead, weight: .medium))
                .foregroundStyle(iconSpec.color)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space1) {
                Text(targetText)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .medium))
                    .foregroundStyle(self.nativePrimaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(typeText)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                    .foregroundStyle(self.nativeTertiaryLabel)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
            .padding(.trailing, MenuBarLayoutTokens.space6)

            HStack(spacing: MenuBarLayoutTokens.space1) {
                if let symbol = badge.symbol {
                    Image(systemName: symbol)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                        .foregroundStyle(badge.color)
                }
                Text(policyText)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                    .foregroundStyle(badge.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 90, alignment: .leading)

            VStack(alignment: .trailing, spacing: MenuBarLayoutTokens.space1) {
                Text("\(stats.count)")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
                    .foregroundStyle(stats.hasProvider ? self.nativeSecondaryLabel : self.nativeTertiaryLabel)
                if let updatedText = stats.updatedText {
                    Text(updatedText)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                        .foregroundStyle(self.nativeTertiaryLabel)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space4)
        .frame(height: MenuBarLayoutTokens.rowHeight, alignment: .center)
        .overlay(alignment: .bottom) {
            if self.showsBottomDivider {
                Rectangle()
                    .fill(self.nativeSeparator)
                    .frame(height: MenuBarLayoutTokens.stroke)
            }
        }
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    private var nativePrimaryLabel: Color {
        Color(nsColor: .labelColor)
    }

    private var nativeSecondaryLabel: Color {
        Color(nsColor: .labelColor)
            .opacity(
                self.isDarkAppearance
                    ? MenuBarLayoutTokens.Theme.Dark.labelSecondary
                    : MenuBarLayoutTokens.Theme.Light.labelSecondary)
    }

    private var nativeTertiaryLabel: Color {
        Color(nsColor: .labelColor)
            .opacity(
                self.isDarkAppearance
                    ? MenuBarLayoutTokens.Theme.Dark.labelTertiary
                    : MenuBarLayoutTokens.Theme.Light.labelTertiary)
    }

    private var nativeSeparator: Color {
        Color(nsColor: .separatorColor)
            .opacity(
                self.isDarkAppearance
                    ? MenuBarLayoutTokens.Theme.Dark.separator
                    : MenuBarLayoutTokens.Theme.Light.separator)
    }

    private var nativeAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    private var nativeInfo: Color {
        Color(nsColor: .systemBlue)
    }

    private var nativeTeal: Color {
        Color(nsColor: .systemTeal)
    }

    private var nativeWarning: Color {
        Color(nsColor: .systemOrange)
    }

    private var nativeIndigo: Color {
        Color(nsColor: .systemIndigo)
    }

    private func ruleTypeIcon(for type: String) -> (symbol: String, color: Color) {
        let lower = type.lowercased()
        if lower.contains("ipcidr") {
            return ("globe.americas.fill", nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if lower.contains("domain") || lower.contains("suffix") || lower.contains("keyword") {
            return ("network", nativeTeal.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if lower.contains("ruleset") {
            return ("list.bullet.rectangle.fill", nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        return ("circle.grid.2x2.fill", nativeIndigo.opacity(MenuBarLayoutTokens.Opacity.solid))
    }

    private func rulePolicyBadge(for policy: String) -> (symbol: String?, color: Color) {
        let lower = policy.lowercased()
        if lower.contains("fishy") {
            return (
                symbol: "exclamationmark.triangle.fill",
                color: nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        return (
            symbol: nil,
            color: nativeSecondaryLabel)
    }

    private func ruleStats(payload: String) -> (count: Int, updatedText: String?, hasProvider: Bool) {
        let payloadTrimmed = payload.trimmed
        guard !payloadTrimmed.isEmpty, payloadTrimmed != tr("ui.common.na") else {
            return (count: 0, updatedText: nil, hasProvider: false)
        }

        if let provider = providerLookup[payloadTrimmed.lowercased()] {
            let count = max(0, provider.ruleCount ?? 0)
            return (
                count: count,
                updatedText: ValueFormatter.relativeTime(from: provider.updatedAt, language: language),
                hasProvider: true)
        }
        return (count: 0, updatedText: nil, hasProvider: false)
    }
}

// MARK: - AppKit table (avoids SwiftUI ScrollView / hosting layout bugs in the panel)

struct RulesListNSTableView: NSViewRepresentable {
    var rules: [RuleItem]
    var providerLookup: [String: ProviderDetail]
    var language: AppLanguage
    var contentWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = .init()
        scrollView.scrollerStyle = .overlay

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = MenuBarLayoutTokens.rowHeight
        tableView.rowSizeStyle = .custom
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        if #available(macOS 11.0, *) {
            tableView.style = .fullWidth
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rule"))
        column.isEditable = false
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        column.minWidth = 80
        column.maxWidth = 10_000
        tableView.addTableColumn(column)

        scrollView.documentView = tableView

        context.coordinator.tableView = tableView
        context.coordinator.applyColumnWidth(contentWidth)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyColumnWidth(contentWidth)
        context.coordinator.tableView?.reloadData()
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: RulesListNSTableView
        weak var tableView: NSTableView?

        init(_ parent: RulesListNSTableView) {
            self.parent = parent
        }

        func applyColumnWidth(_ width: CGFloat) {
            guard let tableView, let column = tableView.tableColumns.first else { return }
            column.width = max(80, width)
        }

        func numberOfRows(in _: NSTableView) -> Int {
            self.parent.rules.count
        }

        func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
            let id = NSUserInterfaceItemIdentifier("RulesHostingCell")
            let cell =
                tableView.makeView(withIdentifier: id, owner: self) as? HostingRulesTableCell
                ?? HostingRulesTableCell()
            cell.identifier = id
            let rule = self.parent.rules[row]
            cell.configure(
                rule: rule,
                providerLookup: self.parent.providerLookup,
                language: self.parent.language,
                contentWidth: self.parent.contentWidth)
            return cell
        }

        func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
            MenuBarLayoutTokens.rowHeight
        }
    }
}

private final class HostingRulesTableCell: NSTableCellView {
    private var hostingView: NSHostingView<AnyView>?

    func configure(
        rule: RuleItem,
        providerLookup: [String: ProviderDetail],
        language: AppLanguage,
        contentWidth: CGFloat)
    {
        let root = AnyView(
            RulesListRowView(
                rule: rule,
                providerLookup: providerLookup,
                language: language,
                showsBottomDivider: true)
                .frame(width: contentWidth, height: MenuBarLayoutTokens.rowHeight))

        if let hostingView {
            hostingView.rootView = root
        } else {
            let hosting = NSHostingView(rootView: root)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: self.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            ])
            self.hostingView = hosting
        }
    }
}

// MARK: - Panel (pinned SwiftUI chrome + AppKit list)

struct MenuBarRulesTablePanel<Header: View>: View {
    let totalHeight: CGFloat
    let contentWidth: CGFloat
    let rules: [RuleItem]
    let providerLookup: [String: ProviderDetail]
    let language: AppLanguage
    @ViewBuilder let header: () -> Header

    var body: some View {
        VStack(spacing: 0) {
            self.header()
                .frame(width: self.contentWidth, alignment: .leading)

            if self.rules.isEmpty {
                Text(L10n.t("ui.empty.rules", language: self.language))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, MenuBarLayoutTokens.space4)
                    .padding(.vertical, MenuBarLayoutTokens.space8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                GeometryReader { proxy in
                    RulesListNSTableView(
                        rules: self.rules,
                        providerLookup: self.providerLookup,
                        language: self.language,
                        contentWidth: self.contentWidth)
                        .frame(width: self.contentWidth, height: max(1, proxy.size.height))
                }
            }
        }
        .frame(width: self.contentWidth, height: self.totalHeight, alignment: .topLeading)
        .clipped()
    }
}
