import AppKit
import SwiftUI

enum NonActivatingTextFieldStyle {
    case plain
    case roundedBorder
}

/// An AppKit-backed text field that refuses first-responder status until the
/// user explicitly clicks it, preventing the menu panel from auto-focusing the
/// first input when it opens.
struct NonActivatingTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var style: NonActivatingTextFieldStyle = .roundedBorder
    var alignment: NSTextAlignment = .natural
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    var onChange: () -> Void = {}
    var onSubmit: (() -> Void)?

    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NonActivatingNSTextField {
        let field = NonActivatingNSTextField()
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.configure(field)
        return field
    }

    func updateNSView(_ nsView: NonActivatingNSTextField, context: Context) {
        nsView.isEnabled = self.isEnabled
        self.configure(nsView)

        // Only push the binding value when the user is not actively editing.
        if nsView.currentEditor() == nil, nsView.stringValue != self.text {
            nsView.stringValue = self.text
        }
    }

    private func configure(_ field: NonActivatingNSTextField) {
        field.placeholderString = self.placeholder
        field.font = self.font
        field.alignment = self.alignment
        field.lineBreakMode = self.lineBreakMode
        field.textColor = .labelColor
        field.placeholderAttributedString = NSAttributedString(
            string: self.placeholder,
            attributes: [.foregroundColor: NSColor.placeholderTextColor])

        switch self.style {
        case .plain:
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false
            field.bezelStyle = .squareBezel
            field.focusRingType = .none
            field.backgroundColor = .clear
        case .roundedBorder:
            field.isBordered = true
            field.isBezeled = true
            field.drawsBackground = true
            field.bezelStyle = .roundedBezel
            field.focusRingType = .default
            field.backgroundColor = .textBackgroundColor
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NonActivatingTextField

        init(parent: NonActivatingTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            self.parent.text = field.stringValue
            self.parent.onChange()
        }

        func control(
            _ control: NSControl,
            textView _: NSTextView,
            doCommandBy commandSelector: Selector) -> Bool
        {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)),
                  let onSubmit = self.parent.onSubmit else {
                return false
            }

            onSubmit()
            control.window?.makeFirstResponder(nil)
            return true
        }
    }
}

/// A text field subclass that refuses first-responder status on the initial
/// responder-chain query, but still allows normal click-to-focus editing.
final class NonActivatingNSTextField: NSTextField {
    private var userDidClick = false

    override var acceptsFirstResponder: Bool {
        self.userDidClick
    }

    override func mouseDown(with event: NSEvent) {
        self.userDidClick = true
        super.mouseDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            self.userDidClick = false
        }
        return resigned
    }
}
