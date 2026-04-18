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

    @ObservedObject var store: RemoteMachineStore
    let localControllerDisplay: String
    let onSwitchTarget: (MachineTarget) -> Void
    let onClose: () -> Void

    @State private var editorMode: EditorMode?
    @Environment(\.colorScheme) private var colorScheme

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "catbar.ui.language") ?? "") ?? .zhHans
    }

    private var panelWidth: CGFloat {
        436
    }

    private var panelHeight: CGFloat {
        500
    }

    private var outerPadding: CGFloat {
        14
    }

    private var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    private var panelBackground: Color {
        Color(nsColor: .windowBackgroundColor).opacity(self.isDarkAppearance ? 0.96 : 0.985)
    }

    private var primaryTextColor: Color {
        Color(nsColor: .labelColor)
    }

    private var secondaryTextColor: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.labelSecondary : MenuBarLayoutTokens.Theme.Light.labelSecondary)
    }

    private var tertiaryTextColor: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.labelTertiary : MenuBarLayoutTokens.Theme.Light.labelTertiary)
    }

    private var borderColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? 0.28 : 0.12)
    }

    private var separatorColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.separator : MenuBarLayoutTokens.Theme.Light.separator)
    }

    private var cardFill: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.045)
        }
        return Color.white.opacity(0.72)
    }

    private var cardHoverFill: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.085)
        }
        return Color.white.opacity(0.88)
    }

    private var cardSelectedFill: Color {
        self.accentTint.opacity(self.isDarkAppearance ? 0.14 : 0.10)
    }

    private var accentTint: Color {
        Color(nsColor: .controlAccentColor)
    }

    private var managerPalette: RemoteMachineManagerPalette {
        .init(
            cardPadding: 10,
            cardCornerRadius: 10,
            trailingActionAreaWidth: 58,
            primaryTextColor: self.primaryTextColor,
            secondaryTextColor: self.secondaryTextColor,
            tertiaryTextColor: self.tertiaryTextColor,
            borderColor: self.borderColor,
            separatorColor: self.separatorColor,
            cardFill: self.cardFill,
            cardHoverFill: self.cardHoverFill,
            cardSelectedFill: self.cardSelectedFill,
            accentTint: self.accentTint,
            isDarkAppearance: self.isDarkAppearance)
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
        .frame(width: self.panelWidth, height: self.panelHeight, alignment: .topLeading)
        .background(
            AppMaterialSurface(
                cornerRadius: 14,
                fallbackStyle: .material(.regularMaterial),
                stroke: self.separatorColor)
        )
        .background(self.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .fill(self.accentTint.opacity(self.isDarkAppearance ? 0.18 : 0.12))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: self.isEditing ? "square.and.pencil" : "point.3.connected.trianglepath.dotted")
                            .font(.app(size: 12, weight: .semibold))
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
                    self.onClose()
                }
            } label: {
                Image(systemName: self.isEditing ? "chevron.left" : "xmark")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                    .foregroundStyle(self.tertiaryTextColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.black.opacity(self.isDarkAppearance ? 0.18 : 0.04),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, self.outerPadding)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(self.separatorColor)
                .frame(height: MenuBarLayoutTokens.stroke)
        }
    }

    private var listContent: some View {
        RemoteMachineListView(
            store: self.store,
            localControllerDisplay: self.localControllerDisplay,
            palette: self.managerPalette,
            onSelectTarget: { target in
                self.onSwitchTarget(target)
                self.onClose()
            },
            onAdd: {
                self.editorMode = .add
            },
            onEdit: { machine in
                self.editorMode = .edit(machine)
            },
            onDelete: { machine in
                self.store.removeMachine(id: machine.id)
            })
    }

    private func editorContent(for mode: EditorMode) -> some View {
        RemoteMachineEditorCard(
            store: self.store,
            machine: mode.machine,
            palette: self.managerPalette,
            onCancel: {
                self.editorMode = nil
            },
            onSave: {
                self.editorMode = nil
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
