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
            VStack(alignment: .leading, spacing: 16) {
                FeedCardView(
                    post: post,
                    currentUserId: authViewModel.currentUserId,
                    badges: badges,
                    onLike: { Task { await toggleLike(post) } },
                    onComment: { showComments = true },
                    onUserTap: {},
                    onReport: { reason in Task { await submitReport(reason, for: post) } },
                    onBlock: { Task { await blockAuthor(of: post) } }
                )
                .padding(.horizontal)

                if !post.climbSequence.isEmpty {
                    climbBreakdown(post)
                        .padding(.horizontal)
                }
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

    // MARK: - Climb breakdown

    /// Every climb of the session as chips, always expanded — the detail
    /// screen is where the full story lives.
    private func climbBreakdown(_ post: PostModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EVERY CLIMB")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Color.geckoPrimary)

            FlowLayout(spacing: 6, rowSpacing: 6) {
                ForEach(post.groupedChips()) { group in
                    ClimbChipView(grade: group.grade, outcome: group.outcome, count: group.count)
                }
            }

            let tally = post.outcomeTally
            HStack(spacing: 14) {
                detailStat(value: "\(post.climbSequence.count)", label: "Climbs")
                detailStat(value: "\(tally.sends)", label: "Sends")
                detailStat(value: "\(tally.flashes)", label: "Flashes")
                if let minutes = post.sessionDurationMinutes, minutes > 0 {
                    detailStat(value: SessionStripView.formatDuration(minutes), label: "Time")
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func detailStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Color.geckoSecondaryText)
        }
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
