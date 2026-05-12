import SwiftUI
import UIKit

/// Renders a 1080x1350 vertical image of a talking point with GoalDigger
/// branding. Used by callers that want to share a branded image instead of
/// raw text (welcome lines, quiz results, future surfaces).
struct ShareableTalkingPointCard: View {
    let text: String
    let teamShortName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text(text)
                .font(.jakarta(36, weight: .semiBold))
                .foregroundColor(.warmWhite)
                .multilineTextAlignment(.leading)
                .lineSpacing(8)
            Spacer()
            HStack {
                if let team = teamShortName {
                    Text(team.uppercased())
                        .font(.jakarta(14, weight: .semiBold))
                        .foregroundColor(.hotRose)
                        .tracking(2)
                }
                Spacer()
                Text("GoalDigger")
                    .font(.jakarta(14, weight: .semiBold))
                    .foregroundColor(.hotRose)
            }
        }
        .padding(48)
        .frame(width: 1080, height: 1350)
        .background(Color.deepMauve)
    }
}

/// Renders a `ShareableTalkingPointCard` to a UIImage at 1x scale.
/// Returns nil if the renderer fails. Call on the main actor.
@MainActor
func renderTalkingPointImage(text: String, teamShortName: String?) -> UIImage? {
    let renderer = ImageRenderer(content: ShareableTalkingPointCard(text: text, teamShortName: teamShortName))
    renderer.scale = 1.0
    return renderer.uiImage
}

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
