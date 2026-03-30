import SwiftUI

enum RootTab: String, CaseIterable, Hashable {
    case proxy
    case nodes
    case rules
    case connections
    case logs
    case system

    var titleKey: String {
        switch self {
        case .proxy: "ui.tab.proxy"
        case .nodes: "ui.tab.nodes"
        case .rules: "ui.tab.rules"
        case .connections: "ui.tab.connections"
        case .logs: "ui.tab.logs"
        case .system: "ui.tab.system"
        }
    }

    var symbolName: String {
        switch self {
        case .proxy: "square.grid.2x2.fill"
        case .nodes: "server.rack"
        case .rules: "arrow.left.arrow.right"
        case .connections: "link"
        case .logs: "doc.fill"
        case .system: "gearshape.fill"
        }
    }
}

enum LogLevelFilter: Hashable, CaseIterable {
    case info
    case warning
    case error

    var titleKey: String {
        switch self {
        case .info: "ui.log_filter.info"
        case .warning: "ui.log_filter.warning"
        case .error: "ui.log_filter.error"
        }
    }
}

private struct LogsRefreshToken: Equatable {
    let logs: [AppErrorLogEntry]
    let sources: Set<AppLogSource>
    let levels: Set<LogLevelFilter>
    let keyword: String
}

struct MenuBarRootView: View {
    enum ProxyCommandCopyTarget: Equatable {
        case local
        case currentEndpoint
    }

    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var connectionsStore: ConnectionsStore
    @EnvironmentObject var remoteMachineStore: RemoteMachineStore
    @EnvironmentObject var popoverLayoutModel: PopoverLayoutModel
    @Environment(\.colorScheme) var colorScheme

    @StateObject var rootViewModel = MenuBarRootViewModel()
    @StateObject var connectionsViewModel = ConnectionsTabViewModel()
    @StateObject var logsViewModel = LogsTabViewModel()
    @StateObject var rulesViewModel = RulesTabViewModel()
    @StateObject var nodesViewModel = NodesTabViewModel()
    @Namespace var segmentedSelectionNamespace

    @State var switchingMode: CoreMode?
    @State var isSwitchingMachine = false
    @State var showRemoteMachineManager = false
    @State var copiedProxyCommandTarget: ProxyCommandCopyTarget?
    @State var proxyCommandCopyResetTask: Task<Void, Never>?
    @State var hoveredRuleID: String?
    @State var hoveredMode: CoreMode?
    @State var hoveredTab: RootTab?
    @State var topHeaderHeight: CGFloat = 0
    @State var modeAndTabSectionHeight: CGFloat = 0
    @State var footerBarHeight: CGFloat = 0
    @State var naturalPanelContentHeight: CGFloat = 0
    @State var rulesHeaderHeight: CGFloat = 0
    @State var connectionsHeaderHeight: CGFloat = 0
    @State var logsHeaderHeight: CGFloat = 0
    @AppStorage("clashbar.proxy.group.hide_hidden") var hideHiddenProxyGroups: Bool = true
    @AppStorage("clashbar.proxy.group.sort_nodes_by_latency") var sortGroupNodesByLatency: Bool = false

    var contentWidth: CGFloat {
        MenuBarLayoutTokens.panelWidth - (MenuBarLayoutTokens.space8 * 2)
    }

    var language: AppLanguage {
        self.appSession.uiLanguage
    }

    func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.t(key, language: self.language, args: args)
    }

    func setCurrentTabWithoutAnimation(_ tab: RootTab) {
        guard self.rootViewModel.currentTab != tab else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.rootViewModel.syncCurrentTab(tab)
        }
    }

    var body: some View {
        self.panelContent
            .frame(width: MenuBarLayoutTokens.panelWidth, alignment: .topLeading)
        .onDisappear {
            self.proxyCommandCopyResetTask?.cancel()
            self.proxyCommandCopyResetTask = nil
        }
    }

    private var panelSections: some View {
        VStack(spacing: 0) {
            topHeader
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .header) }

            modeAndTabSection
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .modeAndTab) }

            Group {
                self.tabScrollAreaContent
            }

            Spacer(minLength: 0)

            footerBar
                .frame(maxWidth: .infinity, alignment: .leading)
                .reportHeight { updateSectionHeight($0, target: .footer) }
        }
    }

    private var styledPanelContent: some View {
        self.panelSections
            .frame(width: self.contentWidth, alignment: .topLeading)
            .padding(.horizontal, MenuBarLayoutTokens.space8)
            .background(alignment: .topLeading) {
                self.naturalPanelMeasurementLayer
            }
            .frame(width: MenuBarLayoutTokens.panelWidth, height: self.resolvedPanelHeight, alignment: .topLeading)
            .background(self.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: MenuBarLayoutTokens.panelCornerRadius, style: .continuous))
    }

    var panelContent: some View {
        self.styledPanelContent
            .onAppear {
                self.setCurrentTabWithoutAnimation(self.appSession.activeMenuTab)
                self.appSession.setActiveMenuTab(self.rootViewModel.currentTab)
                self.refreshDerivedData(for: self.rootViewModel.currentTab)
                self.rootViewModel.updateFilteredProxyGroups(
                    from: self.appSession.proxyGroups,
                    hideHiddenGroups: self.hideHiddenProxyGroups,
                    currentMode: self.appSession.currentMode)
                self.publishPreferredPanelHeight()
            }
            .onChange(of: self.rootViewModel.currentTab) { tab in
                if tab != .connections {
                    self.connectionsViewModel.cancelPendingVisibleConnectionsCoalesce()
                }
                self.appSession.setActiveMenuTab(tab)
                self.refreshDerivedData(for: tab)
                self.publishPreferredPanelHeight()
            }
            .onChange(of: self.appSession.activeMenuTab) { tab in
                guard self.rootViewModel.currentTab != tab else { return }
                self.setCurrentTabWithoutAnimation(tab)
                if tab != .connections {
                    self.connectionsViewModel.cancelPendingVisibleConnectionsCoalesce()
                }
                self.refreshDerivedData(for: tab)
                self.publishPreferredPanelHeight()
            }
            .onChange(of: self.popoverLayoutModel.maxPanelHeight) { _ in
                self.publishPreferredPanelHeight()
            }
            .onChange(of: self.connectionsStore.connectionsRevision) { _ in
                guard self.rootViewModel.currentTab == .connections else { return }
                let searchText: (ConnectionSummary) -> String = { self.connectionSearchText(for: $0) }
                self.connectionsViewModel.scheduleCoalescedVisibleConnectionsUpdate(
                    connectionsSupplier: { self.connectionsStore.connections },
                    searchText: searchText)
            }
            .onChange(of: self.connectionsViewModel.filterText) { _ in
                self.refreshConnectionsDerivedDataIfVisible()
            }
            .onChange(of: self.connectionsViewModel.transportFilter) { _ in
                self.refreshConnectionsDerivedDataIfVisible()
            }
            .onChange(of: self.connectionsViewModel.sortOption) { _ in
                self.refreshConnectionsDerivedDataIfVisible()
            }
            .onChange(of: LogsRefreshToken(
                    logs: self.appSession.errorLogs,
                    sources: self.logsViewModel.selectedSources,
                    levels: self.logsViewModel.selectedLevels,
                    keyword: self.logsViewModel.searchText))
            { _ in
                self.refreshLogsDerivedDataIfVisible()
                }
                .onChange(of: self.appSession.rulesPresentationRevision) { _ in
                    self.refreshRulesDerivedDataIfVisible()
                    }
                    .onChange(of: self.appSession.proxyGroups) { newGroups in
                            self.rootViewModel.updateFilteredProxyGroups(
                                from: newGroups,
                                hideHiddenGroups: self.hideHiddenProxyGroups,
                                currentMode: self.appSession.currentMode)
                        }
                        .onChange(of: self.hideHiddenProxyGroups) { _ in
                            self.rootViewModel.updateFilteredProxyGroups(
                                from: self.appSession.proxyGroups,
                                hideHiddenGroups: self.hideHiddenProxyGroups,
                                currentMode: self.appSession.currentMode)
                        }
                        .onChange(of: self.appSession.currentMode) { mode in
                            self.rootViewModel.updateFilteredProxyGroups(
                                from: self.appSession.proxyGroups,
                                hideHiddenGroups: self.hideHiddenProxyGroups,
                                currentMode: mode)
                        }
    }

    @ViewBuilder
    func tabBody(for tab: RootTab, isMeasuring: Bool = false) -> some View {
        switch tab {
        case .proxy:
            self.proxyTabBody(isMeasuring: isMeasuring)
        case .nodes:
            self.nodesTabBody(isMeasuring: isMeasuring)
        case .rules:
            self.rulesTabBody(isMeasuring: isMeasuring)
        case .connections:
            self.connectionsTabBody(isMeasuring: isMeasuring)
        case .logs:
            self.logsTabBody(isMeasuring: isMeasuring)
        case .system:
            self.systemTabBody // doesn't have large lists
        }
    }

    func tabContent(for tab: RootTab, isMeasuring: Bool = false) -> some View {
        self.tabBody(for: tab, isMeasuring: isMeasuring)
            .padding(.top, MenuBarLayoutTokens.space2)
            .frame(width: self.contentWidth, alignment: .topLeading)
            .id(tab)
    }

    private var naturalPanelMeasurementLayer: some View {
        VStack(spacing: 0) {
            topHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            modeAndTabSection
                .frame(maxWidth: .infinity, alignment: .leading)

            self.tabContent(for: self.rootViewModel.currentTab, isMeasuring: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            footerBar
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: self.contentWidth, alignment: .topLeading)
        .reportHeight { self.updateNaturalPanelContentHeight($0) }
        .hidden()
        .allowsHitTesting(false)
    }

    var panelBackground: some View {
        AppMaterialSurface(
            cornerRadius: MenuBarLayoutTokens.panelCornerRadius,
            fallbackStyle: .material(.regularMaterial),
            stroke: nativeSeparator)
            .shadow(
                color: Color(nsColor: .shadowColor).opacity(MenuBarLayoutTokens.Shadow.standard.opacity),
                radius: MenuBarLayoutTokens.Shadow.standard.radius,
                x: MenuBarLayoutTokens.Shadow.standard.x,
                y: MenuBarLayoutTokens.Shadow.standard.y)
    }

    func refreshDerivedData(for tab: RootTab) {
        switch tab {
        case .proxy:
            Task { await self.appSession.refreshSystemProxyHelperRuntimeSnapshot() }
            return
        case .nodes:
            return
        case .system:
            return
        case .rules:
            self.refreshVisibleRules()
        case .connections:
            self.refreshVisibleConnections()
        case .logs:
            self.refreshVisibleLogs()
        }
    }

    func refreshConnectionsDerivedDataIfVisible() {
        guard self.rootViewModel.currentTab == .connections else { return }
        self.refreshVisibleConnections()
    }

    func refreshLogsDerivedDataIfVisible() {
        guard self.rootViewModel.currentTab == .logs else { return }
        self.refreshVisibleLogs()
    }

    func refreshRulesDerivedDataIfVisible() {
        guard self.rootViewModel.currentTab == .rules else { return }
        self.refreshVisibleRules()
    }
}
