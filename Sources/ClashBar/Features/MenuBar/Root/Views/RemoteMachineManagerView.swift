import SwiftUI

struct RemoteMachineManagerView: View {
    private enum EditorMode {
        case add
        case edit(RemoteMachine)

        var machine: RemoteMachine? {
            switch self {
            case .add:
                nil
            case let .edit(machine):
                machine
            }
        }
    }

    private enum RowAction: Hashable {
        case edit
        case delete

        var symbol: String {
            switch self {
            case .edit:
                "pencil"
            case .delete:
                "trash"
            }
        }

        var accessibilityKey: String {
            switch self {
            case .edit:
                "ui.machine.edit"
            case .delete:
                "ui.action.delete"
            }
        }

        var isDestructive: Bool {
            switch self {
            case .edit:
                false
            case .delete:
                true
            }
        }
    }

    private struct HoveredRowAction: Hashable {
        let machineID: UUID
        let action: RowAction
    }

    @ObservedObject var store: RemoteMachineStore
    let localControllerDisplay: String
    let onSwitchTarget: (MachineTarget) -> Void

    @State private var editorMode: EditorMode?
    @State private var hoveredMachineID: UUID?
    @State private var hoveredRowAction: HoveredRowAction?
    @State private var hoveringLocalCard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appSession: AppSession

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "catbar.ui.language") ?? "") ?? .zhHans
    }

    private var panelWidth: CGFloat {
        MenuBarLayoutTokens.panelWidth
    }

    private var panelHeight: CGFloat {
        448
    }

    private var outerPadding: CGFloat {
        12
    }

    private var cardPadding: CGFloat {
        8
    }

    private var cardCornerRadius: CGFloat {
        10
    }

    private var trailingActionAreaWidth: CGFloat {
        54
    }

    private var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    private var panelBackground: Color {
        Color(nsColor: self.isDarkAppearance ? .windowBackgroundColor : .controlBackgroundColor)
    }

    private var panelBorderColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? 0.26 : 0.12)
    }

    private var primaryTextColor: Color {
        Color(nsColor: .labelColor)
    }

    private var secondaryTextColor: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.labelSecondary : MenuBarLayoutTokens.Theme
                .Light.labelSecondary)
    }

    private var tertiaryTextColor: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.labelTertiary : MenuBarLayoutTokens.Theme
                .Light.labelTertiary)
    }

    private var borderColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? 0.22 : 0.10)
    }

    private var separatorColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.separator : MenuBarLayoutTokens.Theme.Light
                .separator)
    }

    private var cardFill: Color {
        Color(nsColor: self.isDarkAppearance ? .controlBackgroundColor : .windowBackgroundColor)
            .opacity(self.isDarkAppearance ? 0.72 : 0.86)
    }

    private var cardHoverFill: Color {
        self.nativeHoverTint.opacity(self.isDarkAppearance ? 0.20 : 0.14)
    }

    private var cardSelectedFill: Color {
        self.accentTint.opacity(self.isDarkAppearance ? 0.11 : 0.07)
    }

    private var cardSelectedBorder: Color {
        self.accentTint.opacity(self.isDarkAppearance ? 0.42 : 0.22)
    }

    private var sectionFill: Color {
        self.cardFill.opacity(self.isDarkAppearance ? 0.78 : 0.90)
    }

    private var sectionBorderColor: Color {
        self.borderColor.opacity(self.isDarkAppearance ? 0.92 : 0.78)
    }

    private var rowSelectedFill: Color {
        self.accentTint.opacity(self.isDarkAppearance ? 0.13 : 0.08)
    }

    private var nativeHoverTint: Color {
        Color(nsColor: .selectedContentBackgroundColor)
    }

    private var accentTint: Color {
        Color(nsColor: .controlAccentColor)
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isEditing: Bool {
        self.editorMode != nil
    }

    private var headerTitle: String {
        if let editorMode {
            switch editorMode {
            case .add:
                self.tr("ui.machine.add")
            case .edit:
                self.tr("ui.machine.edit")
            }
        } else {
            self.tr("ui.machine.manage")
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.panelCornerRadius, style: .continuous)
                .fill(self.panelBackground)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            self.accentTint.opacity(self.isDarkAppearance ? 0.12 : 0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: MenuBarLayoutTokens.panelCornerRadius, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.panelCornerRadius, style: .continuous)
                        .stroke(self.panelBorderColor, lineWidth: MenuBarLayoutTokens.stroke)
                }

            VStack(alignment: .leading, spacing: 0) {
                self.headerBar
                Group {
                    if let editorMode {
                        self.editorContent(for: editorMode)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        self.listContent
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(self.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: self.panelWidth, height: self.panelHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: MenuBarLayoutTokens.panelCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(self.isDarkAppearance ? 0.22 : 0.12), radius: 20, x: 0, y: 10)
        .animation(.snappy(duration: 0.18), value: self.isEditing)
        .onAppear {
            self.store.startPeriodicConnectivityChecks()
        }
        .onDisappear {
            self.store.stopPeriodicConnectivityChecks()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(self.accentTint.opacity(self.isDarkAppearance ? 0.18 : 0.10))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "network")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                            .foregroundStyle(self.accentTint)
                    }

                Text(self.headerTitle)
                    .font(.app(size: 13, weight: .semibold))
                    .foregroundStyle(self.primaryTextColor)
            }

            Spacer(minLength: 0)

            Button {
                if self.isEditing {
                    self.editorMode = nil
                } else {
                    self.dismiss()
                }
            } label: {
                Image(systemName: self.isEditing ? "chevron.left" : "xmark")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                    .foregroundStyle(self.tertiaryTextColor)
                    .frame(width: 24, height: 24)
                    .background(
                        self.cardFill,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(self.borderColor.opacity(0.9), lineWidth: MenuBarLayoutTokens.stroke)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, self.outerPadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(self.separatorColor)
                .frame(height: MenuBarLayoutTokens.stroke)
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.machineSection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            self.primaryActionButton(title: self.tr("ui.machine.add"), systemImage: "plus") {
                self.editorMode = .add
            }
        }
    }

    private var machineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(self.tr("ui.machine.sources"))
                    .font(.app(size: 10, weight: .bold))
                    .foregroundStyle(self.tertiaryTextColor)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                Text("\(self.store.machines.count + 1)")
                    .font(.app(size: 10, weight: .semibold))
                    .foregroundStyle(self.secondaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(self.badgeBackgroundFill, in: Capsule())
            }

            ScrollView {
                VStack(spacing: 0) {
                    self.localCard
                    Rectangle()
                        .fill(self.separatorColor)
                        .frame(height: MenuBarLayoutTokens.stroke)
                        .padding(.leading, 36)

                    ForEach(Array(self.store.machines.enumerated()), id: \.element.id) { index, machine in
                        self.remoteCard(machine)
                        if index < self.store.machines.count - 1 {
                            Rectangle()
                                .fill(self.separatorColor)
                                .frame(height: MenuBarLayoutTokens.stroke)
                                .padding(.leading, 36)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(self.sectionBackground)
    }

    private var localCard: some View {
        let isActive = self.store.activeTarget.isLocal
        let hovered = self.hoveringLocalCard

        return self.sourceCard(
            title: self.tr("ui.machine.local"),
            subtitle: self.localControllerDisplay,
            iconSymbol: "desktopcomputer",
            iconTint: self.localSourceTint,
            isActive: isActive,
            isSelectionEnabled: !isActive,
            hovered: hovered,
            onSelect: {
                self.onSwitchTarget(.local)
                self.dismiss()
            },
            badges: {
                self.localStatusBadge
            },
            trailing: {
                if isActive {
                    self.activeIndicator
                }
            })
        .onHover { self.hoveringLocalCard = $0 }
    }

    private func remoteCard(_ machine: RemoteMachine) -> some View {
        let status = self.store.statusFor(machine.id)
        let isActive = self.store.activeTargetID == machine.id
        let isSwitchEnabled = !isActive
        let hovered = self.hoveredMachineID == machine.id

        return self.sourceCard(
            title: machine.name,
            subtitle: machine.displayAddress,
            iconSymbol: "network",
            iconTint: self.statusTint(status, active: isActive),
            isActive: isActive,
            isSelectionEnabled: isSwitchEnabled,
            hovered: hovered,
            onSelect: {
                self.onSwitchTarget(.remote(machine))
                self.dismiss()
            },
            badges: {
                self.sourceStatusBadge(status)
            },
            trailing: {
                self.remoteCardTrailing(
                    machineID: machine.id,
                    isActive: isActive,
                    emphasized: hovered,
                    editAction: { self.editorMode = .edit(machine) },
                    deleteAction: { self.store.removeMachine(id: machine.id) })
            })
        .onHover { isHovering in
            self.hoveredMachineID = isHovering ? machine.id : nil
            if !isHovering, self.hoveredRowAction?.machineID == machine.id {
                self.hoveredRowAction = nil
            }
        }
        .contextMenu {
            Button(self.tr("ui.machine.edit")) {
                self.editorMode = .edit(machine)
            }
            Divider()
            Button(self.tr("ui.action.delete"), role: .destructive) {
                self.store.removeMachine(id: machine.id)
            }
        }
    }

    @ViewBuilder
    private func sourceCard<Badges: View, Trailing: View>(
        title: String,
        subtitle: String?,
        iconSymbol: String,
        iconTint: Color,
        isActive: Bool,
        isSelectionEnabled: Bool,
        hovered: Bool,
        onSelect: @escaping () -> Void,
        @ViewBuilder badges: () -> Badges,
        @ViewBuilder trailing: () -> Trailing) -> some View
    {
        HStack(spacing: 8) {
            Button {
                guard isSelectionEnabled else { return }
                onSelect()
            } label: {
                HStack(spacing: 8) {
                    self.iconTile(symbol: iconSymbol, tint: iconTint)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.app(size: 12, weight: .semibold))
                                .foregroundStyle(self.primaryTextColor)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                badges()
                            }
                        }

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.app(size: 10, weight: .regular))
                                .foregroundStyle(self.secondaryTextColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 34, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            trailing()
                .frame(width: self.trailingActionAreaWidth, alignment: .trailing)
        }
        .padding(self.cardPadding)
        .background(self.cardBackground(selected: isActive, hovered: hovered))
    }

    private var localSourceTint: Color {
        switch self.appSession.localRuntimeVisualStatus {
        case .runningHealthy:
            .green
        case .runningDegraded:
            .green
        case .starting, .failed, .stopped:
            self.tertiaryTextColor
        }
    }

    private func editorContent(for mode: EditorMode) -> some View {
        RemoteMachineEditorCard(
            store: self.store,
            machine: mode.machine,
            surfaceFill: self.cardFill,
            borderColor: self.borderColor,
            separatorColor: self.separatorColor,
            secondaryTextColor: self.secondaryTextColor,
            tertiaryTextColor: self.tertiaryTextColor,
            onCancel: {
                self.editorMode = nil
            },
            onSave: {
                self.editorMode = nil
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func primaryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.app(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                .fill(self.accentTint))
        .overlay {
            RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                .stroke(self.accentTint.opacity(0.65), lineWidth: MenuBarLayoutTokens.stroke)
        }
        .shadow(color: Color.black.opacity(self.isDarkAppearance ? 0.20 : 0.10), radius: 10, x: 0, y: 4)
    }

    private func iconTile(symbol: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.opacity(self.isDarkAppearance ? 0.16 : 0.10))
            .frame(width: 24, height: 24)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }

    private var localStatusBadge: some View {
        self.sourcePill(
            title: self.localStatusTitle,
            tint: self.localSourceTint,
            fill: self.localSourceTint.opacity(self.isDarkAppearance ? 0.18 : 0.10),
            showsProgress: self.isLocalRuntimeStarting)
    }

    private var isLocalRuntimeStarting: Bool {
        if case .starting = self.appSession.localRuntimeVisualStatus {
            return true
        }
        return false
    }

    private var localStatusTitle: String {
        switch self.appSession.localRuntimeVisualStatus {
        case .runningHealthy, .runningDegraded:
            self.tr("ui.machine.status_connected")
        case .starting:
            self.tr("ui.machine.status_checking")
        case .failed, .stopped:
            self.tr("ui.machine.status_unreachable")
        }
    }

    private var activeIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.app(size: 12, weight: .bold))
            .foregroundStyle(self.accentTint)
            .frame(width: 22, height: 22)
            .background(self.accentTint.opacity(self.isDarkAppearance ? 0.18 : 0.10), in: Capsule())
    }

    @ViewBuilder
    private func sourceStatusBadge(_ status: MachineConnectionStatus) -> some View {
        switch status {
        case .unknown:
            self.sourcePill(
                title: self.tr("ui.machine.status_unknown"),
                tint: self.tertiaryTextColor,
                fill: self.badgeBackgroundFill)
        case .checking:
            self.sourcePill(
                title: self.tr("ui.machine.status_checking"),
                tint: self.tertiaryTextColor,
                fill: self.badgeBackgroundFill,
                showsProgress: true)
        case .connected:
            self.sourcePill(
                title: self.tr("ui.machine.status_connected"),
                tint: Color(nsColor: .systemGreen),
                fill: Color(nsColor: .systemGreen).opacity(self.isDarkAppearance ? 0.18 : 0.10))
        case .failed:
            self.sourcePill(
                title: self.tr("ui.machine.status_unreachable"),
                tint: self.tertiaryTextColor,
                fill: self.badgeBackgroundFill)
        }
    }

    private var badgeBackgroundFill: Color {
        Color(nsColor: .quaternaryLabelColor).opacity(self.isDarkAppearance ? 0.24 : 0.12)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
            .fill(self.sectionFill)
            .overlay {
                RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                    .stroke(self.sectionBorderColor, lineWidth: MenuBarLayoutTokens.stroke)
            }
    }

    private func sourcePill(title: String, tint: Color, fill: Color, showsProgress: Bool = false) -> some View {
        HStack(spacing: 4) {
            if showsProgress {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.62)
            }

            Text(title)
                .font(.app(size: 8, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(fill, in: Capsule())
    }

    @ViewBuilder
    private func remoteCardTrailing(
        machineID: UUID,
        isActive: Bool,
        emphasized: Bool,
        editAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void) -> some View
    {
        HStack(spacing: 6) {
            if self.store.isRefreshing(machineID) {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.72)
                    .frame(width: 8, height: 8)
            }

            if isActive {
                self.activeIndicator
            } else {
                self.inlineActionGroup(
                    machineID: machineID,
                    emphasized: emphasized,
                    editAction: editAction,
                    deleteAction: deleteAction)
            }
        }
    }

    private func inlineActionButton(
        machineID: UUID,
        rowAction: RowAction,
        emphasized: Bool,
        action: @escaping () -> Void) -> some View
    {
        let hoveredAction = HoveredRowAction(machineID: machineID, action: rowAction)
        let isHovered = self.hoveredRowAction == hoveredAction
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let tint = self.actionButtonTint(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let fill = self.actionButtonFill(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let border = self.actionButtonBorder(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let opacity = (emphasized || isHovered) ? 1.0 : 0.84

        return Button(action: action) {
            Image(systemName: rowAction.symbol)
                .font(.app(size: 9, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(shape.fill(fill))
                .overlay {
                    shape.stroke(border, lineWidth: MenuBarLayoutTokens.stroke)
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .accessibilityLabel(self.tr(rowAction.accessibilityKey))
        .onHover { isHovering in
            self
                .hoveredRowAction = isHovering ? hoveredAction :
                (self.hoveredRowAction == hoveredAction ? nil : self.hoveredRowAction)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: emphasized)
    }

    private func inlineActionGroup(
        machineID: UUID,
        emphasized: Bool,
        editAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void) -> some View
    {
        HStack(spacing: 3) {
            self.inlineActionButton(machineID: machineID, rowAction: .edit, emphasized: emphasized, action: editAction)
            self.inlineActionButton(
                machineID: machineID,
                rowAction: .delete,
                emphasized: emphasized,
                action: deleteAction)
        }
    }

    private func actionButtonTint(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if rowAction.isDestructive {
            return hovered ? .red : .red.opacity(emphasized ? 0.92 : 0.70)
        }

        return hovered ? self.accentTint : self.tertiaryTextColor.opacity(emphasized ? 1 : 0.88)
    }

    private func actionButtonFill(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if hovered {
            if rowAction.isDestructive {
                return Color.red.opacity(self.isDarkAppearance ? 0.18 : 0.10)
            }
            return self.accentTint.opacity(self.isDarkAppearance ? 0.18 : 0.09)
        }

        if emphasized {
            return Color.black.opacity(self.isDarkAppearance ? 0.18 : 0.06)
        }

        return Color.black.opacity(self.isDarkAppearance ? 0.12 : 0.035)
    }

    private func actionButtonBorder(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if hovered {
            return rowAction.isDestructive
                ? Color.red.opacity(self.isDarkAppearance ? 0.48 : 0.28)
                : self.accentTint.opacity(self.isDarkAppearance ? 0.48 : 0.28)
        }

        return self.borderColor.opacity(emphasized ? 1 : (self.isDarkAppearance ? 0.94 : 0.78))
    }

    private func cardBackground(selected: Bool, hovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
            .fill(selected ? self.rowSelectedFill : (hovered ? self.cardHoverFill : .clear))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                        .stroke(self.cardSelectedBorder, lineWidth: MenuBarLayoutTokens.stroke)
                }
            }
    }

    private func statusTint(_ status: MachineConnectionStatus, active _: Bool) -> Color {
        switch status {
        case .unknown, .checking:
            self.tertiaryTextColor
        case .connected:
            Color(red: 0.10, green: 0.73, blue: 0.34)
        case .failed:
            self.tertiaryTextColor
        }
    }
}

private struct RemoteMachineEditorCard: View {
    private enum Field {
        case name
        case host
        case port
        case secret
    }

    @ObservedObject var store: RemoteMachineStore
    let machine: RemoteMachine?
    let surfaceFill: Color
    let borderColor: Color
    let separatorColor: Color
    let secondaryTextColor: Color
    let tertiaryTextColor: Color
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "9090"
    @State private var secret: String = ""
    @State private var useHTTPS = false
    @State private var webPanelEnabled = false
    @FocusState private var focusedField: Field?

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "catbar.ui.language") ?? "") ?? .zhHans
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isValid: Bool {
        !self.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.host.trimmingCharacters(in: .whitespaces).isEmpty &&
            (Int(self.port) ?? 0) > 0 &&
            (Int(self.port) ?? 0) <= 65535
    }

    private var connectionPreview: String {
        let resolvedHost = self.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "controller.example.com"
            : self.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPort = self.port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "9090"
            : self.port.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = self.useHTTPS ? "https" : "http"
        return "\(scheme)://\(resolvedHost):\(resolvedPort)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.name.trimmingCharacters(in: .whitespaces).isEmpty ? self.tr("ui.machine.field.name") : self
                    .name)
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(self.connectionPreview)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.secondaryTextColor)
                    .lineLimit(1)
            }

            VStack(spacing: 0) {
                self.formTextRow(
                    title: self.tr("ui.machine.field.name"),
                    placeholder: self.tr("ui.machine.field.name"),
                    text: self.$name,
                    field: .name)
                self.separator
                self.formTextRow(
                    title: self.tr("ui.machine.field.host"),
                    placeholder: self.tr("ui.machine.field.host"),
                    text: self.$host,
                    field: .host)
                self.separator
                self.portProtocolRow
                self.separator
                self.secretRow
                self.separator
                self.webPanelRow
            }
            .background(self.formSurface)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                self.secondaryActionButton(title: self.tr("ui.action.cancel"), action: self.onCancel)
                self.primaryActionButton(title: self.tr("ui.machine.save"), action: self.save)
                    .disabled(!self.isValid)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let machine {
                self.name = machine.name
                self.host = machine.host
                self.port = "\(machine.port)"
                self.secret = machine.secret ?? ""
                self.useHTTPS = machine.useHTTPS
                self.webPanelEnabled = machine.webPanelEnabled ?? false
            } else {
                self.focusedField = .name
            }
        }
    }

    private func formTextRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field) -> some View
    {
        HStack(spacing: 10) {
            Text(title)
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: 13, weight: .regular))
                .focused(self.$focusedField, equals: field)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var portProtocolRow: some View {
        HStack(spacing: 10) {
            Text(self.tr("ui.machine.field.port"))
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            TextField(self.tr("ui.machine.field.port"), text: self.$port)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: 13, weight: .regular))
                .frame(width: 92)
                .focused(self.$focusedField, equals: .port)

            Spacer(minLength: 0)

            Toggle("HTTPS", isOn: self.$useHTTPS)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.app(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var secretRow: some View {
        HStack(spacing: 10) {
            Text(self.tr("ui.machine.field.secret"))
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            SecureField(self.tr("ui.machine.field.secret"), text: self.$secret)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: 13, weight: .regular))
                .focused(self.$focusedField, equals: .secret)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var webPanelRow: some View {
        HStack(spacing: 10) {
            Text(self.tr("ui.machine.field.web_panel"))
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)
            
            Toggle("", isOn: self.$webPanelEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var separator: some View {
        Rectangle()
            .fill(self.separatorColor)
            .frame(height: MenuBarLayoutTokens.stroke)
    }

    private var formSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(self.surfaceFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 3)
    }

    private func secondaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(self.surfaceFill))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
        }
    }

    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlAccentColor)))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .controlAccentColor).opacity(0.65), lineWidth: MenuBarLayoutTokens.stroke)
        }
    }

    private func save() {
        let trimmedName = self.name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = self.host.trimmingCharacters(in: .whitespaces)
        let portValue = Int(self.port) ?? 9090
        let trimmedSecret = self.secret.trimmingCharacters(in: .whitespaces)

        if let existing = self.machine {
            var updated = existing
            updated.name = trimmedName
            updated.host = trimmedHost
            updated.port = portValue
            updated.secret = trimmedSecret.isEmpty ? nil : trimmedSecret
            updated.useHTTPS = self.useHTTPS
            updated.webPanelEnabled = self.webPanelEnabled
            self.store.updateMachine(updated)
        } else {
            self.store.addMachine(
                RemoteMachine(
                    name: trimmedName,
                    host: trimmedHost,
                    port: portValue,
                    secret: trimmedSecret.isEmpty ? nil : trimmedSecret,
                    useHTTPS: self.useHTTPS,
                    webPanelEnabled: self.webPanelEnabled))
        }

        self.onSave()
    }
}
