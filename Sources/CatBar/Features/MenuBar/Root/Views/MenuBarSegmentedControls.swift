import SwiftUI

private enum SegmentedControlStyle {
    case tab

    var selectionBackgroundID: String {
        switch self {
        case .tab:
            "tab-segmented-selection-background"
        }
    }

    var selectionIndicatorID: String {
        switch self {
        case .tab:
            "tab-segmented-selection-indicator"
        }
    }

    var indicatorWidth: CGFloat {
        switch self {
        case .tab:
            16
        }
    }

    var indicatorBottomPadding: CGFloat {
        switch self {
        case .tab:
            2
        }
    }

    var contentVerticalOffset: CGFloat {
        switch self {
        case .tab:
            0
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .tab:
            0
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .tab:
            26
        }
    }

    var stackSpacing: CGFloat {
        switch self {
        case .tab:
            0
        }
    }

    var contentVerticalPadding: CGFloat {
        switch self {
        case .tab:
            2
        }
    }

    func selectedFillOpacity(isDark: Bool) -> CGFloat {
        switch self {
        case .tab:
            isDark ? 0.22 : 0.12
        }
    }

    func selectedBorderOpacity(isDark: Bool) -> CGFloat {
        switch self {
        case .tab:
            isDark ? 0.20 : 0.14
        }
    }

    func hoverFillOpacity(isDark: Bool) -> CGFloat {
        switch self {
        case .tab:
            0
        }
    }

    func selectedForegroundOpacity(isDark: Bool) -> CGFloat {
        switch self {
        case .tab:
            isDark ? 0.96 : 0.92
        }
    }

    func selectedIconOpacity(isDark: Bool) -> CGFloat {
        switch self {
        case .tab:
            isDark ? 0.98 : 0.94
        }
    }

    func shadowOpacity(isDark: Bool) -> CGFloat {
        switch self {
        case .tab:
            isDark ? 0.0 : 0.0
        }
    }

    func shadowRadius(isDark _: Bool) -> CGFloat {
        switch self {
        case .tab:
            0
        }
    }

    func shadowYOffset(isDark _: Bool) -> CGFloat {
        switch self {
        case .tab:
            0
        }
    }
}

extension MenuBarRootView {
    var modeSwitcher: some View {
        HStack(spacing: MenuBarLayoutTokens.space2) {
            self.modeSegmentButton(
                title: tr("ui.mode.rule"),
                mode: .rule,
                symbol: "shield.lefthalf.filled")
            self.modeSegmentButton(
                title: tr("ui.mode.global"),
                mode: .global,
                symbol: "globe")
            self.modeSegmentButton(
                title: tr("ui.mode.direct"),
                mode: .direct,
                symbol: "bolt.fill")
        }
        .frame(width: contentWidth)
    }

    func modeSegmentButton(title: String, mode: CoreMode, symbol: String) -> some View {
        let selected = appSession.currentMode == mode
        let switchingThisMode = switchingMode == mode

        return self.filterChipButton(
            title: title,
            selected: selected,
            symbol: switchingThisMode ? nil : symbol,
            isLoading: switchingThisMode,
            expandsHorizontally: true)
        {
            guard appSession.isModeSwitchEnabled, switchingMode == nil, mode != appSession.currentMode else { return }

            switchingMode = mode
            Task { @MainActor in
                await appSession.switchMode(to: mode)
                switchingMode = nil
            }
        }
        .onHover { hoveredMode = self.nextHovered(current: hoveredMode, target: mode, isHovering: $0) }
        .animation(.snappy(duration: 0.18), value: appSession.currentMode)
        .animation(.easeOut(duration: 0.12), value: hoveredMode)
    }

    var topTabs: some View {
        HStack(spacing: MenuBarLayoutTokens.space2) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                self.tabSegmentButton(tab)
            }
        }
        .frame(width: contentWidth)
    }

    func tabSegmentButton(_ tab: RootTab) -> some View {
        let style = SegmentedControlStyle.tab
        let selected = self.rootViewModel.currentTab == tab
        let hovered = hoveredTab == tab

        return Button {
            guard self.rootViewModel.currentTab != tab else { return }
            withAnimation(.snappy(duration: 0.18)) {
                self.rootViewModel.syncCurrentTab(tab)
            }
        } label: {
            ZStack(alignment: .bottom) {
                Text(self.tr(tab.titleKey))
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                    .foregroundStyle(self.segmentedLabelColor(style: style, selected: selected, hovered: hovered))
                    .frame(maxWidth: .infinity)
                    .frame(height: style.rowHeight)

                if selected {
                    Capsule(style: .continuous)
                        .fill(self.segmentedAccentColor(style: style))
                        .frame(width: style.indicatorWidth, height: 2)
                        .padding(.bottom, style.indicatorBottomPadding)
                        .matchedGeometryEffect(id: style.selectionIndicatorID, in: self.segmentedSelectionNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredTab = self.nextHovered(current: hoveredTab, target: tab, isHovering: $0) }
        .animation(.snappy(duration: 0.18), value: self.rootViewModel.currentTab)
        .animation(.easeOut(duration: 0.12), value: hoveredTab)
    }

    @ViewBuilder
    private func segmentedButtonBackground(
        style: SegmentedControlStyle,
        selected: Bool,
        hovered: Bool) -> some View
    {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)

        if selected {
            Color.clear
        } else if hovered {
            shape
                .fill(self.segmentedHoverFill(style: style))
        } else {
            Color.clear
        }
    }

    private func segmentedLabelColor(style: SegmentedControlStyle, selected: Bool, hovered: Bool) -> Color {
        if selected {
            switch style {
            case .tab:
                return self.nativePrimaryLabel
            }
        }
        if hovered {
            switch style {
            case .tab:
                return self.nativePrimaryLabel.opacity(self.isDarkAppearance ? 0.82 : 0.74)
            }
        }
        return self.nativeSecondaryLabel
    }

    private func segmentedIconColor(style: SegmentedControlStyle, selected: Bool, hovered: Bool) -> Color {
        if selected {
            switch style {
            case .tab:
                return self.segmentedSelectedForeground(style: style)
            }
        }
        if hovered {
            return self.nativeSecondaryLabel.opacity(self.isDarkAppearance ? 0.96 : 0.84)
        }
        return self.nativeTertiaryLabel
    }

    private func segmentedAccentColor(style: SegmentedControlStyle) -> Color {
        if self.isDarkAppearance {
            switch style {
            case .tab:
                Color(red: 0.50, green: 0.72, blue: 0.95)
            }
        } else {
            switch style {
            case .tab:
                Color(red: 0.20, green: 0.40, blue: 0.71)
            }
        }
    }

    private func segmentedSelectionFill(style: SegmentedControlStyle) -> Color {
        switch style {
        case .tab:
            self.segmentedAccentColor(style: style)
                .opacity(style.selectedFillOpacity(isDark: self.isDarkAppearance))
        }
    }

    private func segmentedSelectionBorder(style: SegmentedControlStyle) -> Color {
        switch style {
        case .tab:
            self.segmentedAccentColor(style: style)
                .opacity(style.selectedBorderOpacity(isDark: self.isDarkAppearance))
        }
    }

    private func segmentedSelectionShadow(style: SegmentedControlStyle) -> Color {
        Color.black.opacity(style.shadowOpacity(isDark: self.isDarkAppearance))
    }

    private func segmentedHoverFill(style: SegmentedControlStyle) -> Color {
        switch style {
        case .tab:
            self.nativeHoverFill.opacity(style.hoverFillOpacity(isDark: self.isDarkAppearance))
        }
    }

    private func segmentedSelectedForeground(style: SegmentedControlStyle) -> Color {
        self.segmentedAccentColor(style: style)
            .opacity(style.selectedForegroundOpacity(isDark: self.isDarkAppearance))
    }
}
