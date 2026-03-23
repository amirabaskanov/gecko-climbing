import SwiftUI

struct PostDetailView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    let post: PostModel
    @State private var showComments = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeedCardView(
                    post: post,
                    currentUserId: authViewModel.currentUserId,
                    onLike: {},
                    onComment: { showComments = true },
                    onUserTap: {}
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.geckoBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showComments) {
            CommentsView(viewModel: CommentsViewModel(
                postId: post.postId,
                postRepository: appEnv.postRepository,
                userRepository: appEnv.userRepository,
                userId: authViewModel.currentUserId,
                userDisplayName: authViewModel.currentUserDisplayName,
                userProfileImageURL: ""
            ))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }
}
