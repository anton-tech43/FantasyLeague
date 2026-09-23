import SwiftUI
import UIKit

// ShareableTalkingPointCard and renderTalkingPointImage lived here until
// 2026-09-23: a 1080x1350 branded share image built for "welcome lines, quiz
// results, future surfaces" that no surface ever called. Nothing shares an
// image today; the talking points are copied as text by the button below.

/// Small clipboard button used next to talking points. Copies the text and
/// flips the icon to a checkmark briefly to confirm.
struct CopyButton: View {
    let text: String
    @State private var justCopied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { justCopied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { justCopied = false }
            }
        } label: {
            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.hotRose)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(justCopied ? "Copied" : "Copy talking point")
    }
}
