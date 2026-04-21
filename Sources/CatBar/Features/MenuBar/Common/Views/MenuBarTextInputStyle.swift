import SwiftUI

struct MenuBarTextInputSurfaceModifier: ViewModifier {
    var horizontalPadding: CGFloat = MenuBarLayoutTokens.space6
    var verticalPadding: CGFloat = MenuBarLayoutTokens.space4
    var cornerRadius: CGFloat = MenuBarLayoutTokens.cornerRadius

    @Environment(\.colorScheme) private var colorScheme

    private var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    private var fillColor: Color {
        Color(nsColor: self.isDarkAppearance ? .controlBackgroundColor : .windowBackgroundColor)
            .opacity(self.isDarkAppearance ? 0.54 : 0.38)
    }

    private var borderColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? 0.40 : 0.12)
    }

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, self.horizontalPadding)
            .padding(.vertical, self.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                    .fill(self.fillColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                            .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
                    })
    }
}

extension View {
    func menuBarTextInputSurface(
        horizontalPadding: CGFloat = MenuBarLayoutTokens.space6,
        verticalPadding: CGFloat = MenuBarLayoutTokens.space4,
        cornerRadius: CGFloat = MenuBarLayoutTokens.cornerRadius) -> some View
    {
        modifier(
            MenuBarTextInputSurfaceModifier(
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                cornerRadius: cornerRadius))
    }
}
