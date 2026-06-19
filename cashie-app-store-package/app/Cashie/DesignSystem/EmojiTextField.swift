import SwiftUI
import UIKit

/// SwiftUI wrapper around a UITextField that defaults to the emoji
/// keyboard. SwiftUI's TextField has no public API for this, so we
/// drop to UIKit and override `textInputMode` to pick the emoji
/// keyboard from the user's active input modes. Falls back to the
/// system default if the emoji keyboard is disabled in Settings.
struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var fontSize: CGFloat = 22

    func makeUIView(context: Context) -> _EmojiKeyboardTextField {
        let tf = _EmojiKeyboardTextField(frame: .zero)
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: fontSize)
        tf.textAlignment = .center
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.editingChanged(_:)),
                     for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: _EmojiKeyboardTextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        init(_ parent: EmojiTextField) { self.parent = parent }

        @objc func editingChanged(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }
    }
}

/// UITextField subclass that asks UIKit for the emoji input mode
/// whenever it becomes first responder. The empty
/// `textInputContextIdentifier` keeps iOS from restoring whatever
/// keyboard the user used last.
final class _EmojiKeyboardTextField: UITextField {
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes
        where mode.primaryLanguage == "emoji" {
            return mode
        }
        return super.textInputMode
    }
}
