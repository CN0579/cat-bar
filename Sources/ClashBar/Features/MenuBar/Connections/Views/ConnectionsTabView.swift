import AppKit
import SwiftUI

// MARK: - Layout constants (shared between ConnectionRowView and MenuBarRootView)

private enum ConnectionsLayout {
    static let topLineSpacing: CGFloat = MenuBarLayoutTokens.space2
    static let topMetaSpacing: CGFloat = MenuBarLayoutTokens.space1
    static let secondLineSpacing: CGFloat = MenuBarLayoutTokens.space2
    static let rowLineHeight: CGFloat = 16
    static let topRuleMinWidth: CGFloat = 26
    static let topPayloadMinWidth: CGFloat = 14
    /// = panelWidth - panelContentHPad*2 - rowHPad*2 - leadingIcon - hstackGaps - closeButton
    static let rowContentWidth: CGFloat =
        MenuBarLayoutTokens.panelWidth
            - (MenuBarLayoutTokens.space8 * 2)
            - (MenuBarLayoutTokens.space4 * 2)
            - MenuBarLayoutTokens.rowLeadingIcon
            - (MenuBarLayoutTokens.space6 * 2)
            - 12
}

// MARK: - Equatable row view (isolated from EnvironmentObjects → body skipped when data unchanged)

struct ConnectionRowView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let conn: ConnectionSummary
    let language: AppLanguage
    let isHovered: Bool
    let resolvedHost: String?
    var onClose: () -> Void
    var onHover: (Bool) -> Void
    var onCopyHost: (() -> Void)?
    var onCopyID: () -> Void

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.conn == rhs.conn &&
        lhs.language == rhs.language &&
        lhs.isHovered == rhs.isHovered &&
        lhs.resolvedHost == rhs.resolvedHost
    }

    // MARK: - Text width cache

    private static var textWidthCache: [String: CGFloat] = [:]
    private static let textWidthCacheMaxEntries = 512

    // MARK: - Body

    var body: some View {
        let visual = Self.connectionVisual(for: self.conn, colorScheme: self.colorScheme)
        let hostText = self.conn.metadata?.host.trimmedNonEmpty
            ?? self.conn.metadata?.destinationIP.trimmedNonEmpty
            ?? self.tr("ui.common.na")
        let networkType = self.conn.metadata?.network.trimmedNonEmpty?.uppercased() ?? "--"
        let timeText = Self.connectionTimeOnly(self.conn.start)
        let upText = ValueFormatter.bytesCompactNoSpace(self.conn.upload ?? 0)
        let downText = ValueFormatter.bytesCompactNoSpace(self.conn.download ?? 0)
        let parsedRule = Self.parseConnectionRule(self.conn.rule)
        let ruleTypeText = Self.connectionRuleTypeText(self.conn.rule, fallback: parsedRule?.type)
        let rulePayloadText = self.conn.rulePayload.trimmedNonEmpty
            ?? parsedRule?.payload.trimmedNonEmpty
            ?? "--"

        HStack(alignment: .center, spacing: MenuBarLayoutTokens.space6) {
            Image(systemName: visual.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(visual.color)
                .frame(
                    width: MenuBarLayoutTokens.rowLeadingIcon,
                    height: MenuBarLayoutTokens.rowLeadingIcon,
                    alignment: .center)

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                self.topLine(host: hostText, ruleType: ruleTypeText, rulePayload: rulePayloadText)
                self.metricsLine(time: timeText, network: networkType, up: upText, down: downText)
                self.chainsLine(parts: Self.connectionChainsParts(self.conn.chains))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            self.closeButton
        }
        .padding(.horizontal, MenuBarLayoutTokens.space4)
        .padding(.vertical, MenuBarLayoutTokens.space2)
        .background(self.hoverRowBackground(self.isHovered))
        .onHover { self.onHover($0) }
        .contextMenu { self.contextMenuContent }
    }

    // MARK: - Sub-views

    private func topLine(host: String, ruleType: String, rulePayload: String) -> some View {
        let layout = Self.topLineLayout(
            totalWidth: ConnectionsLayout.rowContentWidth,
            ruleText: ruleType,
            payloadText: rulePayload)

        return HStack(spacing: ConnectionsLayout.topLineSpacing) {
            Text(host)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(self.nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: layout.hostWidth, alignment: .leading)

            HStack(spacing: ConnectionsLayout.topMetaSpacing) {
                self.topBadge(text: ruleType)
                    .frame(width: layout.ruleWidth, alignment: .trailing)
                self.topPayload(text: rulePayload)
                    .frame(width: layout.payloadWidth, alignment: .trailing)
            }
            .frame(
                width: layout.ruleWidth + ConnectionsLayout.topMetaSpacing + layout.payloadWidth,
                alignment: .trailing)
        }
        .frame(height: ConnectionsLayout.rowLineHeight)
    }

    private func metricsLine(time: String, network: String, up: String, down: String) -> some View {
        let columnWidth = max(
            (ConnectionsLayout.rowContentWidth - (ConnectionsLayout.secondLineSpacing * 3)) / 4,
            0)

        return HStack(spacing: ConnectionsLayout.secondLineSpacing) {
            self.metricColumn(
                symbol: "clock",
                text: time,
                fallback: self.tr("ui.common.na"),
                width: columnWidth)
            self.metricColumn(
                symbol: "network",
                text: network,
                fallback: self.tr("ui.common.na"),
                width: columnWidth)
            self.metricColumn(
                symbol: "arrow.up",
                text: up,
                symbolColor: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                textColor: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
                spacing: 0,
                truncation: .tail,
                width: columnWidth)
            self.metricColumn(
                symbol: "arrow.down",
                text: down,
                symbolColor: self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
                textColor: self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
                spacing: 0,
                truncation: .tail,
                width: columnWidth)
        }
        .frame(height: ConnectionsLayout.rowLineHeight)
    }

    private var closeButton: some View {
        Button {
            self.onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(self.isHovered ? self.nativeSecondaryLabel : self.nativeTertiaryLabel)
        .frame(width: 12, height: 12)
        .opacity(self.isHovered ? 1 : 0)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(role: .destructive) {
            self.onClose()
        } label: {
            Label(self.tr("ui.action.close_connection"), systemImage: "xmark.circle")
        }

        if self.resolvedHost != nil {
            Button {
                self.onCopyHost?()
            } label: {
                Label(self.tr("ui.action.copy_host"), systemImage: "doc.on.doc")
            }
        }

        Button {
            self.onCopyID()
        } label: {
            Label(self.tr("ui.action.copy_connection_id"), systemImage: "number")
        }
    }

    private func metricColumn(
        symbol: String,
        text: String,
        symbolColor: Color = .secondary,
        textColor: Color = .secondary,
        fallback: String? = nil,
        spacing: CGFloat = MenuBarLayoutTokens.space2,
        truncation: Text.TruncationMode = .middle,
        width: CGFloat) -> some View
    {
        let renderedText = text.isEmpty ? (fallback ?? "") : text

        return HStack(spacing: spacing) {
            Image(systemName: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 10, alignment: .leading)
            Text(renderedText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(truncation)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }

    private func topBadge(text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(self.nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            .padding(.horizontal, MenuBarLayoutTokens.space2)
            .padding(.vertical, MenuBarLayoutTokens.space1)
            .background(self.nativeBadgeCapsule)
    }

    private func topPayload(text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
            .foregroundStyle(self.nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func chainsLine(parts: [String]) -> some View {
        let chainText = parts.joined(separator: " > ")
        let displayText = parts.isEmpty ? self.tr("ui.common.na") : chainText

        return HStack(spacing: MenuBarLayoutTokens.space2) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(self.nativeSecondaryLabel)
                .frame(width: 10, alignment: .leading)

            Text(displayText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(self.nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: ConnectionsLayout.rowLineHeight, alignment: .leading)
    }

    // MARK: - Theme helpers

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

    private var nativeInfo: Color { Color(nsColor: .systemBlue) }
    private var nativePositive: Color { Color(nsColor: .systemGreen) }
    private var nativeWarning: Color { Color(nsColor: .systemOrange) }
    private var nativePurple: Color { Color(nsColor: .systemPurple) }
    private var nativeIndigo: Color { Color(nsColor: .systemIndigo) }
    private var nativeTeal: Color { Color(nsColor: .systemTeal) }

    private var nativeHoverFill: Color {
        Color(nsColor: .selectedContentBackgroundColor)
            .opacity(
                self.isDarkAppearance
                    ? MenuBarLayoutTokens.Theme.Dark.hoverFill
                    : MenuBarLayoutTokens.Theme.Light.hoverFill)
    }

    private var nativeBadgeCapsule: some View {
        Capsule(style: .continuous)
            .fill(Color(nsColor: .quaternaryLabelColor).opacity(MenuBarLayoutTokens.Opacity.tint))
    }

    private func hoverRowBackground(_ hovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
            .fill(hovered ? self.nativeHoverFill : .clear)
    }

    // MARK: - Static helpers (pure functions — no instance state needed)

    private static func connectionVisual(
        for conn: ConnectionSummary,
        colorScheme: ColorScheme
    ) -> (symbol: String, color: Color) {
        let host = conn.metadata?.host?.lowercased() ?? ""
        let network = conn.metadata?.network?.lowercased() ?? ""
        let isDark = colorScheme == .dark

        let info = Color(nsColor: .systemBlue)
        let positive = Color(nsColor: .systemGreen)
        let warning = Color(nsColor: .systemOrange)
        let purple = Color(nsColor: .systemPurple)
        let indigo = Color(nsColor: .systemIndigo)
        let teal = Color(nsColor: .systemTeal)
        let secondary = Color(nsColor: .labelColor)
            .opacity(isDark ? MenuBarLayoutTokens.Theme.Dark.labelSecondary : MenuBarLayoutTokens.Theme.Light.labelSecondary)

        if host.contains("google") || host.contains("gstatic") {
            return ("shield.fill", purple.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("icloud") || host.contains("apple") {
            return ("icloud.fill", info.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("github") {
            return ("terminal.fill", indigo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("twitter") || host.contains("x.com") {
            return ("lock.fill", positive.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("amazon") {
            return ("cart.fill", warning.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if network.contains("udp") {
            return ("dot.radiowaves.left.and.right", teal.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if network.contains("tcp") {
            return ("network", info.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        return ("globe", secondary)
    }

    private static func connectionTimeOnly(_ input: String?) -> String {
        let full = ValueFormatter.dateTimeFromISO(input)
        guard full != "--" else { return full }
        return full.split(separator: " ").last.map(String.init) ?? full
    }

    private static func connectionRuleTypeText(_ raw: String?, fallback: String?) -> String {
        let candidate = fallback.trimmedNonEmpty ?? raw.trimmedNonEmpty ?? ""
        guard !candidate.isEmpty else { return "--" }
        let normalized = candidate.uppercased()
        if normalized == "MATCH" || normalized == "FINAL" { return "--" }
        return candidate
    }

    static func connectionChainsParts(_ chains: [String]?) -> [String] {
        Array((chains ?? []).compactMap(\.trimmedNonEmpty).reversed())
    }

    private static func parseConnectionRule(_ raw: String?) -> (type: String, payload: String?)? {
        guard let raw = raw.trimmedNonEmpty else { return nil }

        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let type = raw[..<open].trimmed
            let payload = raw[raw.index(after: open)..<close].trimmed
            if let type = type.nonEmpty {
                return (type, payload.nonEmpty)
            }
        }

        let commaParts = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        if commaParts.count == 2 {
            let type = commaParts[0].trimmed
            let payload = commaParts[1].trimmed
            if let type = type.nonEmpty {
                return (type, payload.nonEmpty)
            }
        }

        return (raw, nil)
    }

    private static func topLineLayout(
        totalWidth: CGFloat,
        ruleText: String,
        payloadText: String
    ) -> (hostWidth: CGFloat, ruleWidth: CGFloat, payloadWidth: CGFloat) {
        guard totalWidth > 0 else { return (0, 0, 0) }

        let hostMinWidth = floor(totalWidth * 0.5)
        let metaMaxWidth = max(totalWidth - ConnectionsLayout.topLineSpacing - hostMinWidth, 0)

        var ruleWidth = max(
            ConnectionsLayout.topRuleMinWidth,
            Self.monospacedTextWidth(ruleText, size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold) + 4)
        var payloadWidth = max(
            ConnectionsLayout.topPayloadMinWidth,
            Self.monospacedTextWidth(payloadText, size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
        let desiredMetaWidth = ruleWidth + ConnectionsLayout.topMetaSpacing + payloadWidth

        if desiredMetaWidth > metaMaxWidth {
            var overflow = desiredMetaWidth - metaMaxWidth

            let payloadReducible = max(payloadWidth - ConnectionsLayout.topPayloadMinWidth, 0)
            let payloadReduction = min(overflow, payloadReducible)
            payloadWidth -= payloadReduction
            overflow -= payloadReduction

            if overflow > 0 {
                let ruleReducible = max(ruleWidth - ConnectionsLayout.topRuleMinWidth, 0)
                let ruleReduction = min(overflow, ruleReducible)
                ruleWidth -= ruleReduction
                overflow -= ruleReduction
            }

            if overflow > 0 {
                let metaContentWidth = max(metaMaxWidth - ConnectionsLayout.topMetaSpacing, 0)
                if metaContentWidth <= 0 {
                    ruleWidth = 0
                    payloadWidth = 0
                } else {
                    let total = max(ruleWidth + payloadWidth, 1)
                    let ruleRatio = ruleWidth / total
                    ruleWidth = floor(metaContentWidth * ruleRatio)
                    payloadWidth = max(metaContentWidth - ruleWidth, 0)
                }
            }
        }

        let metaWidth = ruleWidth + ConnectionsLayout.topMetaSpacing + payloadWidth
        let hostWidth = max(totalWidth - ConnectionsLayout.topLineSpacing - metaWidth, hostMinWidth)
        return (hostWidth, ruleWidth, payloadWidth)
    }

    private static func monospacedTextWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let cacheKey = "\(text)\0\(size)\0\(weight.rawValue)"
        if let cached = Self.textWidthCache[cacheKey] { return cached }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: weight),
        ]
        let width = ceil((text as NSString).size(withAttributes: attributes).width)
        if Self.textWidthCache.count >= Self.textWidthCacheMaxEntries {
            Self.textWidthCache.removeAll(keepingCapacity: true)
        }
        Self.textWidthCache[cacheKey] = width
        return width
    }
}

// MARK: - MenuBarRootView connections tab

extension MenuBarRootView {
    func connectionsTabBody(isMeasuring: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space6) {
            self.connectionsTabPinnedHeader
            self.connectionsTabScrollableList(isMeasuring: isMeasuring)
        }
    }

    var connectionsTabPinnedHeader: some View {
        self.connectionsControlCard
    }

    func connectionsTabScrollableList(isMeasuring: Bool = false) -> some View {
        let connections = self.connectionsViewModel.visibleConnections

        return Group {
            if connections.isEmpty {
                self.emptyCard(tr("ui.empty.connections"))
            } else {
                let displayConnections = isMeasuring ? Array(connections.prefix(25)) : connections
                MeasurementAwareVStack(alignment: .leading, spacing: 0, usesLazyStack: false) {
                    SeparatedForEach(data: displayConnections, id: \.id, separator: nativeSeparator) { conn in
                        self.connectionRow(conn)
                    }
                }
            }
        }
    }

    var connectionsControlCard: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.connectionsFilterMenu
                self.connectionsSortMenu

                Spacer(minLength: 0)

                self.fractionSummaryBadge(
                    current: self.connectionsViewModel.visibleConnections.count,
                    total: min(self.connectionsStore.connections.count, 120))

                self.compactTopIcon(
                    "xmark",
                    label: tr("ui.action.close_all"),
                    warning: true)
                {
                    await appSession.closeAllConnections()
                }
                .help(tr("ui.action.close_all"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField(tr("ui.placeholder.filter_connection"), text: $connectionsViewModel.filterText)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
                .foregroundStyle(nativePrimaryLabel)
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.space4)
    }

    var connectionsFilterMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.connectionsViewModel.transportFilter,
            options: ConnectionsTransportFilter.allCases,
            symbol: "line.3.horizontal.decrease.circle",
            helpText: tr("ui.network.filter.transport"),
            optionTitle: { self.tr($0.titleKey) },
            onSelect: { self.connectionsViewModel.transportFilter = $0 }))
    }

    var connectionsSortMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.connectionsViewModel.sortOption,
            options: ConnectionsSortOption.allCases,
            symbol: "arrow.up.arrow.down",
            helpText: tr("ui.network.sort.label"),
            optionTitle: { self.tr($0.titleKey) },
            onSelect: { self.connectionsViewModel.sortOption = $0 }))
    }

    func refreshVisibleConnections() {
        self.connectionsViewModel.updateVisibleConnections(
            from: self.connectionsStore.connections,
            searchText: { connection in
                self.connectionSearchText(for: connection)
            })
    }

    func connectionRow(_ conn: ConnectionSummary) -> some View {
        let hovered = self.connectionsViewModel.hoveredConnectionID == conn.id
        let host = appSession.resolvedConnectionHost(for: conn)

        return ConnectionRowView(
            conn: conn,
            language: self.language,
            isHovered: hovered,
            resolvedHost: host,
            onClose: { Task { await self.appSession.closeConnection(id: conn.id) } },
            onHover: { isHovering in
                self.connectionsViewModel.hoveredConnectionID = self.nextHovered(
                    current: self.connectionsViewModel.hoveredConnectionID, target: conn.id, isHovering: isHovering)
            },
            onCopyHost: host != nil ? { self.appSession.copyConnectionHost(host!) } : nil,
            onCopyID: { self.appSession.copyConnectionID(conn.id) }
        )
        .equatable()
    }

    func connectionSearchText(for conn: ConnectionSummary) -> String {
        let host = conn.metadata?.host ?? ""
        let destinationIP = conn.metadata?.destinationIP ?? ""
        let sourceIP = conn.metadata?.sourceIP ?? ""
        let network = conn.metadata?.network ?? ""
        let id = conn.id
        let rule = conn.rule ?? ""
        let rulePayload = conn.rulePayload ?? ""
        let chains = ConnectionRowView.connectionChainsParts(conn.chains).joined(separator: " > ")
        let start = conn.start ?? ""
        return "\(host) \(destinationIP) \(sourceIP) \(network) \(id) \(rule) \(rulePayload) \(chains) \(start)"
    }
}
