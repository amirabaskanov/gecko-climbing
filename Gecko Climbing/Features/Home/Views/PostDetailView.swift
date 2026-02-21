import SwiftUI

struct PostDetailView: View {
    let post: PostModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeedCardView(post: post, onLike: {}, onUserTap: {})
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.geckoBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
    }
}
