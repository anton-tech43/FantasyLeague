import SwiftUI

// TODO: Implement in I8
struct ContentDetailView: View {
    let item: ContentItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                Text(item.headline)
                    .font(Theme.detailTitle)
                    .foregroundStyle(Theme.textPrimary)

                Text(item.body)
                    .font(Theme.detailBody)
                    .foregroundStyle(Theme.textPrimary)

                if !item.talkingPoints.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.elementSpacing) {
                        Text("Things to say")
                            .font(Theme.feedHeadline)
                            .foregroundStyle(Theme.textSecondary)

                        ForEach(item.talkingPoints, id: \.self) { point in
                            Text(point)
                                .font(Theme.talkingPointText)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }
            .padding(Theme.screenPadding)
        }
        .background(Theme.appBackground)
    }
}
