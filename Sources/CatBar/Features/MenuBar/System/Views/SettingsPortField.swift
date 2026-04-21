import AppKit
import SwiftUI

/// A port text field that does not automatically become first responder when
/// the menu panel appears. The user must explicitly click to start editing.
struct SettingsPortTextField: View {
    let placeholder: String
    @Binding var text: String
    let onChange: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        NonActivatingTextField(
            placeholder: self.placeholder,
            text: self.$text,
            style: .plain,
            alignment: .right,
            font: NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize(for: .regular),
                weight: .regular),
            lineBreakMode: .byTruncatingTail,
            onChange: self.onChange,
            onSubmit: self.onSubmit)
            .menuBarTextInputSurface()
    }
}
