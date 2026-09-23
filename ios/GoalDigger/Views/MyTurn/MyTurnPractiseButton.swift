import SwiftUI

/// The one thing to press. Sits at the top of every My Turn module with room
/// around it, above the browsing surface.
///
/// Anton's read of the first build (2026-09-09): a list of 157 terms, or 24
/// packs, or 25 situations, is a wall to someone who does not know football.
/// The browsing stays, lower down, for the four-second look-up during a match.
/// The first thing she sees is an invitation to practise ten of something.
struct MyTurnPractiseButton: View {
    let title: String
    /// One line under the title saying what she will get: "10 flashcards from
    /// the first ten words", "Continue: question 4 of 10". Keep it concrete.
    let subtitle: String
    var systemImage: String = "play.fill"
    /// Two lines is enough for "Ten questions from The basics". Lingo's
    /// subtitle is a whole sentence about the weekend ("1st against 2nd.
    /// Proper six-pointer. 7 words for it.") and truncates at two.
    var subtitleLineLimit: Int = 2
    let action: () -> Void

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.hotRose)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.warmWhite))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.jakarta(20, weight: .bold))
                        .foregroundColor(.warmWhite)
                    Text(subtitle)
                        .font(.jakarta(14, weight: .regular))
                        .foregroundColor(.warmWhite.opacity(0.85))
                        .lineLimit(subtitleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.warmWhite.opacity(0.8))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.hotRose)
            .cornerRadius(20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The room around it belongs to the screen, not to the button. Twenty
        // eight points of padding OUTSIDE the `Button` was measured frame that
        // was never tappable, and a neighbouring card drawn into it is
        // hit-tested over a hero that looks perfectly fine in a screenshot.
        // Every call site pads itself.
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}
