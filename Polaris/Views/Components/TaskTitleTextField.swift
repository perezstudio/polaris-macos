//
//  TaskTitleTextField.swift
//  Polaris
//

import SwiftUI

struct TaskTitleTextField: NSViewRepresentable {
    @Binding var text: String
    let isFocused: Bool
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDeleteEmpty: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: AppSettings.shared.scaledSize(13))
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.truncatesLastVisibleLine = true
        textField.placeholderString = "New Task"
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        if textField.stringValue != text && !context.coordinator.isEditing {
            textField.stringValue = text
        }

        if isFocused && !context.coordinator.lastAppliedFocus {
            context.coordinator.lastAppliedFocus = true
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
                if let editor = textField.currentEditor() {
                    editor.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                }
            }
        } else if !isFocused {
            context.coordinator.lastAppliedFocus = false
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: TaskTitleTextField
        var isEditing = false
        var lastAppliedFocus = false

        init(_ parent: TaskTitleTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            isEditing = true
            parent.text = textField.stringValue
            isEditing = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel?()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if textView.string.isEmpty {
                    parent.onDeleteEmpty?()
                    return true
                }
            }
            return false
        }
    }
}
