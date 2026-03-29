import SwiftUI

// MARK: - Pinned header configuration (shared by rules / connections / logs)

struct PinnedHeaderTabConfig {
    let headerSpacing: CGFloat
    let headerHeight: CGFloat
    let topPadding: CGFloat = MenuBarLayoutTokens.space2

    var scrollContainerHeight: CGFloat {
        headerSpacing + topPadding
    }
}

extension MenuBarRootView {
    @ViewBuilder
    var tabScrollAreaContent: some View {
        let tab = self.rootViewModel.currentTab

        if let config = self.pinnedHeaderConfig(for: tab), config.headerHeight > 0, self.needsTabScrolling {
            self.pinnedHeaderLayout(for: tab, config: config)
        } else if self.needsTabScrolling {
            ThinScrollContainer(height: self.availableTabScrollAreaHeight) {
                self.tabContent(for: tab)
                    .frame(width: self.contentWidth, alignment: .topLeading)
            }
            .frame(width: self.contentWidth, alignment: .topLeading)
            .background {
                self.pinnedHeaderMeasurementLayer(for: tab)
            }
        } else {
            self.tabContent(for: tab)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func pinnedHeaderConfig(for tab: RootTab) -> PinnedHeaderTabConfig? {
        switch tab {
        case .rules:
            PinnedHeaderTabConfig(headerSpacing: 0, headerHeight: self.rulesHeaderHeight)
        case .connections:
            PinnedHeaderTabConfig(headerSpacing: MenuBarLayoutTokens.space6, headerHeight: self.connectionsHeaderHeight)
        case .logs:
            PinnedHeaderTabConfig(headerSpacing: MenuBarLayoutTokens.space6, headerHeight: self.logsHeaderHeight)
        default:
            nil
        }
    }

    @ViewBuilder
    private func pinnedHeaderLayout(for tab: RootTab, config: PinnedHeaderTabConfig) -> some View {
        let listHeight = max(1, self.availableTabScrollAreaHeight - config.headerHeight - config.scrollContainerHeight)

        VStack(spacing: config.headerSpacing) {
            self.pinnedHeader(for: tab)
                .frame(width: self.contentWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .reportHeight { self.updatePinnedHeaderHeight(tab: tab, height: $0) }

            ThinScrollContainer(height: listHeight) {
                self.pinnedScrollableList(for: tab)
                    .frame(width: self.contentWidth, alignment: .topLeading)
            }
        }
        .padding(.top, config.topPadding)
        .frame(width: self.contentWidth, alignment: .topLeading)
        .id(tab)
    }

    @ViewBuilder
    private func pinnedHeader(for tab: RootTab) -> some View {
        switch tab {
        case .rules:
            self.rulesTabPinnedHeader()
        case .connections:
            self.connectionsTabPinnedHeader
        case .logs:
            self.logsTabPinnedHeader
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func pinnedScrollableList(for tab: RootTab) -> some View {
        switch tab {
        case .rules:
            self.rulesTabScrollableList(isMeasuring: false)
        case .connections:
            self.connectionsTabScrollableList(isMeasuring: false)
        case .logs:
            self.logsTabScrollableList(isMeasuring: false)
        default:
            EmptyView()
        }
    }

    private func updatePinnedHeaderHeight(tab: RootTab, height: CGFloat) {
        switch tab {
        case .rules:
            self.rulesHeaderHeight = height
        case .connections:
            self.connectionsHeaderHeight = height
        case .logs:
            self.logsHeaderHeight = height
        default:
            break
        }
    }

    private var hasMeasuredFixedSections: Bool {
        self.topHeaderHeight > 0 && self.modeAndTabSectionHeight > 0 && self.footerBarHeight > 0
    }

    private var fixedSectionHeight: CGFloat {
        self.topHeaderHeight + self.modeAndTabSectionHeight + self.footerBarHeight
    }

    private var naturalTabContentHeight: CGFloat {
        max(1, self.naturalPanelContentHeight - self.fixedSectionHeight)
    }

    var resolvedPanelHeight: CGFloat {
        guard self.naturalPanelContentHeight > 0 else { return self.popoverLayoutModel.resolvedPanelHeight }
        return min(self.naturalPanelContentHeight, self.popoverLayoutModel.maxPanelHeight)
    }

    var needsTabScrolling: Bool {
        self.naturalPanelContentHeight > self.popoverLayoutModel.maxPanelHeight + 0.5
    }

    var availableTabScrollAreaHeight: CGFloat {
        max(1, self.resolvedPanelHeight - self.fixedSectionHeight)
    }

    func updateSectionHeight(_ measured: CGFloat, target: SectionHeightTarget) {
        let normalized = max(0, measured)

        switch target {
        case .header:
            guard abs(self.topHeaderHeight - normalized) > 0.5 else { return }
            self.topHeaderHeight = normalized
        case .modeAndTab:
            guard abs(self.modeAndTabSectionHeight - normalized) > 0.5 else { return }
            self.modeAndTabSectionHeight = normalized
        case .footer:
            guard abs(self.footerBarHeight - normalized) > 0.5 else { return }
            self.footerBarHeight = normalized
        }
    }

    func updateNaturalPanelContentHeight(_ measured: CGFloat) {
        let normalized = max(1, measured)
        guard abs(self.naturalPanelContentHeight - normalized) > 0.5 else { return }

        self.naturalPanelContentHeight = normalized
        self.publishPreferredPanelHeight()
    }

    func publishPreferredPanelHeight() {
        self.popoverLayoutModel.requestPanelHeight(max(1, self.resolvedPanelHeight.rounded(.up)))
    }

    /// Hidden layer that measures the pinned header height so the next render can
    /// switch to the fixed-header + scroll-list layout without an initial blank flash.
    @ViewBuilder
    func pinnedHeaderMeasurementLayer(for tab: RootTab) -> some View {
        if let config = self.pinnedHeaderConfig(for: tab), config.headerHeight == 0 {
            self.pinnedHeader(for: tab)
                .fixedSize(horizontal: false, vertical: true)
                .reportHeight { self.updatePinnedHeaderHeight(tab: tab, height: $0) }
                .hidden()
                .allowsHitTesting(false)
        }
    }

    enum SectionHeightTarget {
        case header
        case modeAndTab
        case footer
    }
}
