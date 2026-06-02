import SwiftUI

struct PostDetailView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    let postId: String
    @State private var post: PostModel?
    @State private var didFailToLoad = false
    @State private var showComments = false

    /// Preloaded path — the post is already in hand (e.g. tapped from the
    /// feed), so the view renders instantly with no fetch.
    init(post: PostModel) {
        self.postId = post.postId
        _post = State(initialValue: post)
    }

    /// Deep-link path — only the id is known (e.g. a like or comment
    /// notification whose post isn't in the loaded feed). The post is
    /// fetched on appear.
    init(postId: String) {
        self.postId = postId
        _post = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let post {
                postContent(post)
            } else if didFailToLoad {
                ContentUnavailableView(
                    "Post unavailable",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("This post may have been deleted.")
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.geckoBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard post == nil else { return }
            post = try? await appEnv.postRepository.fetchPost(postId: postId)
            didFailToLoad = post == nil
        }
    }

    @ViewBuilder
    private func postContent(_ post: PostModel) -> some View {
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
