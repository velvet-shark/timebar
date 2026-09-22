import AppKit
import SwiftUI
import TimebarCore

@MainActor
struct DurationField: View {
    let title: String
    @Binding var text: String
    let maximum: Int
    let onSubmit: () -> Void

    init(_ title: String, text: Binding<String>, maximum: Int, onSubmit: @escaping () -> Void) {
        self.title = title
        self._text = text
        self.maximum = maximum
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ComponentEditor(text: $text, title: title, maximum: maximum, onSubmit: onSubmit)
                    .frame(minWidth: 24, maxWidth: .infinity)
                Stepper(title, onIncrement: { step(1) }, onDecrement: { step(-1) })
                    .labelsHidden()
                    .controlSize(.mini)
                    .fixedSize()
                    .accessibilityLabel("Adjust \(title.lowercased())")
                    .accessibilityValue(text.isEmpty ? "0" : text)
            }
            .padding(.horizontal, 7)
            .frame(height: 37)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func step(_ delta: Int) {
        text = DurationText.steppedComponent(text, by: delta, maximum: maximum)
    }
}

/// Use the native field editor so click and Tab focus both select the existing value.
@MainActor
private struct ComponentEditor: NSViewRepresentable {
    @Binding var text: String
    let title: String
    let maximum: Int
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SelectableNumberField {
        let field = SelectableNumberField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        field.placeholderString = "0"
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setAccessibilityLabel("Custom \(title.lowercased())")
        field.setAccessibilityIdentifier("timebar.custom.\(title.lowercased())")
        return field
    }

    func updateNSView(_ field: SelectableNumberField, context: Context) {
        context.coordinator.parent = self
        let displayed = text == "0" ? "" : text
        guard field.stringValue != displayed else { return }
        field.stringValue = displayed
        if let editor = field.currentEditor() {
            editor.string = displayed
            editor.selectAll(nil)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ComponentEditor

        init(_ parent: ComponentEditor) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let normalized = DurationText.normalizedComponent(field.stringValue) ?? parent.text
            let displayed = normalized == "0" ? "" : normalized
            if displayed != field.stringValue {
                field.stringValue = displayed
                if let editor = field.currentEditor() {
                    editor.string = displayed
                    editor.selectedRange = NSRange(location: displayed.utf16.count, length: 0)
                }
            }
            parent.text = normalized
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField, field.stringValue.isEmpty else { return }
            parent.text = "0"
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)):
                let delta = commandSelector == #selector(NSResponder.moveUp(_:)) ? 1 : -1
                let value = DurationText.steppedComponent(parent.text, by: delta, maximum: parent.maximum)
                let displayed = value == "0" ? "" : value
                parent.text = value
                (control as? NSTextField)?.stringValue = displayed
                textView.string = displayed
                textView.selectAll(nil)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
            }
        }
    }
}

@MainActor
private final class SelectableNumberField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { selectValue() }
        return accepted
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // NSTextField normally moves the caret after becomeFirstResponder during a click.
        selectValue()
    }

    private func selectValue() {
        currentEditor()?.selectAll(nil)
        DispatchQueue.main.async { [weak self] in self?.currentEditor()?.selectAll(nil) }
    }
}
