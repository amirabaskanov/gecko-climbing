import SwiftUI

struct PostDetailView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    let postId: String
    /// Viewer-contextual badges, passed through from the feed. Deep links
    /// arrive without them.
    var badges: [FeedBadge] = []
    @State private var post: PostModel?
    @State private var didFailToLoad = false
    @State private var showComments = false
    @State private var showAuthor = false
    /// One view model for both the inline list and the composer sheet, so a
    /// comment sent from the sheet appears in the thread the moment the
    /// sheet closes.
    @State private var commentsVM: CommentsViewModel?
    @State private var error: Error?

    /// Preloaded path — the post is already in hand (e.g. tapped from the
    /// feed), so the view renders instantly with no fetch.
    init(post: PostModel, badges: [FeedBadge] = []) {
        self.postId = post.postId
        self.badges = badges
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
        .tabBarScrollInset()
        .background(Color.geckoBackground)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(error: $error)
        .task {
            guard post == nil else { return }
            post = try? await appEnv.postRepository.fetchPost(postId: postId)
            didFailToLoad = post == nil
        }
    }

    @ViewBuilder
    private func postContent(_ post: PostModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FeedCardView(
                    post: post,
                    currentUserId: authViewModel.currentUserId,
                    badges: badges,
                    onLike: { Task { await toggleLike(post) } },
                    onComment: { showComments = true },
                    onUserTap: { showAuthor = true },
                    onReport: { reason in Task { await submitReport(reason, for: post) } },
                    onBlock: { Task { await blockAuthor(of: post) } },
                    showsAllClimbs: true
                )

                commentsSection(post)
                    .padding(.top, 20)
            }
            .padding(.bottom, 24)
        }
        .navigationDestination(isPresented: $showAuthor) {
            FriendProfileView(uid: post.userId)
        }
        .task {
            guard commentsVM == nil else { return }
            let vm = CommentsViewModel(
                postId: post.postId,
                postRepository: appEnv.postRepository,
                userRepository: appEnv.userRepository,
                userId: authViewModel.currentUserId,
                userDisplayName: authViewModel.currentUserDisplayName,
                userProfileImageURL: ""
            )
            vm.onCommentCountChanged = { count in
                self.post?.commentsCount = count
            }
            commentsVM = vm
            await vm.loadComments()
        }
        .sheet(isPresented: $showComments) {
            if let commentsVM {
                CommentsView(viewModel: commentsVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Comments (inline, read-only; the sheet owns composing)

    @ViewBuilder
    private func commentsSection(_ post: PostModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SocialSectionHeader(
                title: "Comments",
                detail: (commentsVM?.totalCount ?? post.commentsCount) > 0 ? "\(commentsVM?.totalCount ?? post.commentsCount)" : nil
            )

            if let commentsVM {
                if commentsVM.threads.isEmpty {
                    if commentsVM.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text("No comments yet. Say something about this session.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.geckoSecondaryText)
                            .padding(.horizontal, 16)
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(commentsVM.threads) { thread in
                            CommentRowView(comment: thread.root)
                            ForEach(thread.replies) { reply in
                                CommentRowView(comment: reply, isReply: true)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showComments = true }
                }
            }

            composerPill
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
    }

    /// Looks like an input, acts like a button: opens the composer sheet with
    /// the keyboard up. Keeps the floating tab bar and a real text field from
    /// fighting over the bottom of the screen.
    private var composerPill: some View {
        Button {
            showComments = true
        } label: {
            HStack(spacing: 10) {
                Text("Add a comment")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.geckoSecondaryText)
                Spacer()
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.geckoPrimary.opacity(0.5))
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .frame(height: 46)
            .background(Capsule().fill(Color.geckoInputBackground))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a comment")
    }

    // MARK: - Like

    private func toggleLike(_ post: PostModel) async {
        let wasLiked = post.isLikedByCurrentUser
        post.isLikedByCurrentUser.toggle()
        post.likesCount += wasLiked ? -1 : 1
        do {
            if wasLiked {
                try await appEnv.postRepository.unlikePost(post.postId, userId: authViewModel.currentUserId)
            } else {
                try await appEnv.postRepository.likePost(post.postId, userId: authViewModel.currentUserId)
            }
        } catch {
            post.isLikedByCurrentUser = wasLiked
            post.likesCount += wasLiked ? 1 : -1
            self.error = error
        }
    }

    // MARK: - Moderation (App Store Guideline 1.2)

    private func submitReport(_ reason: ReportModel.Reason, for post: PostModel) async {
        let report = ReportModel(
            reporterUserId: authViewModel.currentUserId,
            targetType: .post,
            targetId: post.postId,
            targetPostId: post.postId,
            targetAuthorId: post.userId,
            reason: reason
        )
        do {
            try await appEnv.feedbackRepository.submitReport(report)
            AnalyticsService.capture(.postReported, properties: ["reason": reason.rawValue])
        } catch {
            self.error = error
        }
    }

    /// Block the author and pop back to the feed; their posts are filtered
    /// on the next feed load now that the block persists.
    private func blockAuthor(of post: PostModel) async {
        do {
            try await appEnv.userRepository.blockUser(post.userId)
            AnalyticsService.capture(.userBlocked)
            dismiss()
        } catch {
            self.error = error
        }
    }
}
