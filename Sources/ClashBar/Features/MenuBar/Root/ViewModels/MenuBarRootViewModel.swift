import Foundation
import SwiftUI

@MainActor
final class MenuBarRootViewModel: ObservableObject {
    @Published var currentTab: RootTab = .proxy
    @Published private(set) var filteredProxyGroups: [ProxyGroup] = []
    private let globalGroupName = "GLOBAL"

    func syncCurrentTab(_ tab: RootTab) {
        self.currentTab = tab
    }

    func updateFilteredProxyGroups(from groups: [ProxyGroup], hideHiddenGroups: Bool, currentMode: CoreMode) {
        let nextGroups = self.filterProxyGroups(groups, hideHiddenGroups: hideHiddenGroups, currentMode: currentMode)
        guard nextGroups != self.filteredProxyGroups else { return }
        self.filteredProxyGroups = nextGroups
    }

    private func filterProxyGroups(
        _ groups: [ProxyGroup],
        hideHiddenGroups: Bool,
        currentMode: CoreMode) -> [ProxyGroup]
    {
        let modeFilteredGroups: [ProxyGroup]
        switch currentMode {
        case .rule:
            modeFilteredGroups = groups.filter { $0.name != self.globalGroupName }
        case .global:
            modeFilteredGroups = groups.filter { $0.name == self.globalGroupName }
        case .direct:
            modeFilteredGroups = []
        }

        if hideHiddenGroups {
            return modeFilteredGroups.filter { $0.hidden != true }
        }

        return modeFilteredGroups
    }
}
