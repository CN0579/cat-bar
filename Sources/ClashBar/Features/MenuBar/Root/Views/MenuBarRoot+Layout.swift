import SwiftUI

extension MenuBarRootView {
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

    enum SectionHeightTarget {
        case header
        case modeAndTab
        case footer
    }
}
