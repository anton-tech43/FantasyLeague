import SwiftUI
import UIKit

/// UIKit-backed text field for onboarding screens.
///
/// We use this instead of SwiftUI `TextField` because the app forces dark
/// mode (`UIUserInterfaceStyle = Dark` in Info.plist), and under forced
/// dark mode SwiftUI's `TextField` has focus-state behaviour that ignores
/// `.background()` colours — making the field appear transparent and
/// turning charcoal-on-cream text into invisible charcoal-on-mauve.
///
/// `overrideUserInterfaceStyle = .light` set on the `UITextField` directly
/// bypasses the issue at the UIKit layer where SwiftUI environment values
/// don't reach.
struct OnboardingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var autofocus: Bool = true
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.overrideUserInterfaceStyle = .light
        // Paint the UITextField the same softBlush as the SwiftUI wrapper. UITextField
        // in focused state under forced dark mode applies internal dark visualisations
        // even when backgroundColor is .clear; matching the outer fill makes them invisible.
        tf.backgroundColor = UIColor(Color.cardBackground)
        tf.borderStyle = .none
        tf.font = UIFont(name: "PlusJakartaSans-Medium", size: 20)
            ?? .systemFont(ofSize: 20, weight: .medium)
        tf.textColor = UIColor(Color.textPrimaryOnCard)
        tf.tintColor = UIColor(Color.hotRose)
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(Color.textPrimaryOnCard.opacity(0.4))]
        )
        tf.autocapitalizationType = .words
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.textChanged),
                     for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if autofocus && !context.coordinator.didAutofocus {
            context.coordinator.didAutofocus = true
            // Delay long enough for the wrapper's RoundedRectangle.fill to
            // finish painting. becomeFirstResponder() during the first layout
            // pass races with the SwiftUI background and leaves a dark inner
            // stripe under forced dark mode.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: OnboardingTextField
        var didAutofocus = false

        init(_ parent: OnboardingTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return true
        }
    }
}
