import SwiftUI

/// Full content detail view with talking points.
/// Full implementation in task I8.
struct ContentDetailView: View {
    let item: ContentItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.headline)
                    .font(.title2.weight(.bold))
                Text(item.body)
                    .font(.body)
                if !item.talkingPoints.isEmpty {
                    Text("Things to Say")
                        .font(.headline)
                    ForEach(item.talkingPoints, id: \.self) { point in
                        Text(point)
                            .font(.callout)
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
