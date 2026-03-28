import SwiftUI

// TODO: Implement in I12
struct ContentCard: View {
    let item: ContentItem

    var body: some View {
        Text(item.headline)
            .font(Theme.feedHeadline)
            .cardStyle()
    }
}
