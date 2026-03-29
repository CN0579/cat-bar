import SwiftUI

extension MenuBarRootView {
    @ViewBuilder
    var tabScrollAreaContent: some View {
        let tab = self.rootViewModel.currentTab
        if self.needsTabScrolling, tab == .rules, self.rulesHeaderHeight > 0 {
            VStack(spacing: 0) {
                self.rulesTabPinnedHeader()
                    .frame(width: self.contentWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .reportHeight { self.rulesHeaderHeight = $0 }

                ThinScrollContainer(height: max(1, self.availableTabScrollAreaHeight - self.rulesHeaderHeight - MenuBarLayoutTokens.space2)) {
                    self.rulesTabScrollableList(isMeasuring: false)
                        .frame(width: self.contentWidth, alignment: .topLeading)
                }
            }
            .padding(.top, MenuBarLayoutTokens.space2)
            .frame(width: self.contentWidth, alignment: .topLeading)
            .id(tab)
        } else if self.needsTabScrolling, tab == .connections, self.connectionsHeaderHeight > 0 {
            VStack(spacing: MenuBarLayoutTokens.space6) {
                self.connectionsTabPinnedHeader
                    .frame(width: self.contentWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .reportHeight { self.connectionsHeaderHeight = $0 }

                ThinScrollContainer(height: max(1, self.availableTabScrollAreaHeight - self.connectionsHeaderHeight - MenuBarLayoutTokens.space2 - MenuBarLayoutTokens.space6)) {
                    self.connectionsTabScrollableList(isMeasuring: false)
                        .frame(width: self.contentWidth, alignment: .topLeading)
                }
            }
            .padding(.top, MenuBarLayoutTokens.space2)
            .frame(width: self.contentWidth, alignment: .topLeading)
            .id(tab)
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
        switch tab {
        case .rules where self.rulesHeaderHeight == 0:
            self.rulesTabPinnedHeader()
                .fixedSize(horizontal: false, vertical: true)
                .reportHeight { self.rulesHeaderHeight = $0 }
                .hidden()
                .allowsHitTesting(false)
        case .connections where self.connectionsHeaderHeight == 0:
            self.connectionsTabPinnedHeader
                .fixedSize(horizontal: false, vertical: true)
                .reportHeight { self.connectionsHeaderHeight = $0 }
                .hidden()
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }

    enum SectionHeightTarget {
        case header
        case modeAndTab
        case footer
    }
}
