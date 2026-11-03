import SwiftUI

/// A section with a tappable header that expands to reveal its content.
/// Used in SettingsView for "Change your setup" and "About". Collapsed
/// by default on each view appearance — no persistence (a user revisits
/// settings often; defaulting to collapsed keeps the screen compact).
///
/// The open/closed flag belongs to the caller: kept in this view's own
/// `@State`, Delete My Data › Cancel came back with both sections folded
/// and the page at the top, so she had to open About again to retry (bug
/// hunt 2026-11-03 U-C10). Settings keeps it in the gear that presents it.
///
/// Visual: rose-tinted uppercase title matching `settingsSection`
/// headers, chevron-down (collapsed) / chevron-up (expanded), spring
/// animation on toggle. Content slides in from the top with opacity.
struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack {
                    Text(title.uppercased())
                        .font(.jakarta(11, weight: .semiBold))
                        .tracking(1)
                        .foregroundColor(.hotRose.opacity(0.7))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.hotRose.opacity(0.7))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}
