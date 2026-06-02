import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Bindable var router: TabRouter<HomeRoute>
    @State private var viewModel: HomeViewModel?
    @State private var appeared = false
    @State private var commentsPostId: String?
    var refreshToken: UUID = UUID()

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if let vm = viewModel {
                    content(vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.geckoBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    GeckoLogoView(size: 28, color: .geckoPrimary, showWordmark: true)
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .postDetail(let postId):
                    let candidates = (viewModel?.followingPosts ?? []) + (viewModel?.discoverPosts ?? [])
                    if let post = candidates.first(where: { $0.postId == postId }) {
                        PostDetailView(post: post)
                    } else {
                        // Deep-linked from a notification — the post isn't in
                        // the loaded feed, so load it by id.
                        PostDetailView(postId: postId)
                    }
                case .friendProfile(let uid):
                    FriendProfileView(uid: uid)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = HomeViewModel(
                    postRepository: appEnv.postRepository,
                    userRepository: appEnv.userRepository,
                    sessionRepository: appEnv.sessionRepository,
                    userId: authViewModel.currentUserId
                )
                vm.userDisplayName = authViewModel.currentUserDisplayName
                viewModel = vm
                Task { await vm.loadFeed() }
            }
        }
        .onChange(of: refreshToken) {
            Task { await viewModel?.loadFeed() }
        }
        .sheet(isPresented: Binding(
            get: { commentsPostId != nil },
            set: { if !$0 { commentsPostId = nil } }
        )) {
            if let postId = commentsPostId, let vm = viewModel {
                let commentsVM = CommentsViewModel(
                    postId: postId,
                    postRepository: vm.postRepository,
                    userRepository: appEnv.userRepository,
                    userId: vm.userId,
                    userDisplayName: vm.userDisplayName,
                    userProfileImageURL: vm.userProfileImageURL
                )
                CommentsView(viewModel: commentsVM)
                    .onAppear {
                        commentsVM.onCommentCountChanged = { count in
                            vm.updateCommentCount(postId: postId, count: count)
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            FeedRailSwitcher(
                selection: $vm.currentRail,
                hasFreshDiscover: !vm.discoverPosts.isEmpty
            )

            // Crossfade between rails so the switch feels like a soft pivot,
            // not a navigation push. Each rail keeps its own scroll position
            // because they're separate view trees.
            ZStack {
                if vm.currentRail == .following {
                    followingRail(vm)
                        .transition(.opacity)
                } else {
                    discoverRail(vm)
                        .transition(.opacity)
                }
            }
            .animation(.geckoSnappy, value: vm.currentRail)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.geckoBackground)
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 })) {
            Task { await vm.loadFeed() }
        }
    }

    // MARK: - Following rail

    @ViewBuilder
    private func followingRail(_ vm: HomeViewModel) -> some View {
        if vm.isLoadingFollowing && vm.followingPosts.isEmpty {
            loadingState
        } else if vm.followingPosts.isEmpty {
            followingEmptyState(vm)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(vm.followingPosts.enumerated()), id: \.element.id) { index, post in
                        FeedCardView(
                            post: post,
                            currentUserId: authViewModel.currentUserId,
                            badges: vm.badges(for: post),
                            onLike: { Task { await vm.toggleLike(post) } },
                            onComment: { commentsPostId = post.postId },
                            onUserTap: { router.push(.friendProfile(uid: post.userId)) },
                            onCardTap: { router.push(.postDetail(postId: post.postId)) }
                        )
                        .padding(.horizontal, 16)
                        .staggeredAppear(index: index, appeared: appeared)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .contentMargins(.bottom, 48)
            .background(Color.geckoBackground)
            .refreshable { await vm.loadFeed() }
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }

    @ViewBuilder
    private func followingEmptyState(_ vm: HomeViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    GeckoLogoView(size: 64, color: .geckoPrimary.opacity(0.7))
                        .padding(.top, 32)
                    Text("Your feed is quiet — for now")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Follow climbers to see their sessions, sends, and projects right here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        withAnimation(.geckoSnappy) { vm.currentRail = .discover }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Browse Discover")
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Color.geckoPrimary))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                if !vm.suggestedClimbers.isEmpty {
                    SuggestedClimbersCarousel(
                        users: vm.suggestedClimbers,
                        followingIds: vm.followingIds,
                        onFollow: { user in Task { await vm.follow(user) } },
                        onUnfollow: { user in Task { await vm.unfollow(user) } },
                        onTap: { user in router.push(.friendProfile(uid: user.uid)) }
                    )
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 48)
        }
        .contentMargins(.bottom, 48)
        .refreshable { await vm.loadFeed() }
    }

    // MARK: - Discover rail

    @ViewBuilder
    private func discoverRail(_ vm: HomeViewModel) -> some View {
        if vm.isLoadingDiscover && vm.discoverPosts.isEmpty {
            loadingState
        } else if vm.discoverPosts.isEmpty && vm.suggestedClimbers.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "No public posts yet",
                    subtitle: "Be the first to share a session — it'll appear here for everyone."
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            }
            .refreshable { await vm.loadFeed() }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !vm.suggestedClimbers.isEmpty {
                        SuggestedClimbersCarousel(
                            users: vm.suggestedClimbers,
                            followingIds: vm.followingIds,
                            onFollow: { user in Task { await vm.follow(user) } },
                            onUnfollow: { user in Task { await vm.unfollow(user) } },
                            onTap: { user in router.push(.friendProfile(uid: user.uid)) }
                        )
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }

                    ForEach(Array(vm.discoverPosts.enumerated()), id: \.element.id) { index, post in
                        FeedCardView(
                            post: post,
                            currentUserId: authViewModel.currentUserId,
                            badges: vm.badges(for: post),
                            onLike: { Task { await vm.toggleLike(post) } },
                            onComment: { commentsPostId = post.postId },
                            onUserTap: { router.push(.friendProfile(uid: post.userId)) },
                            onCardTap: { router.push(.postDetail(postId: post.postId)) }
                        )
                        .padding(.horizontal, 16)
                        .staggeredAppear(index: index, appeared: appeared)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .contentMargins(.bottom, 48)
            .background(Color.geckoBackground)
            .refreshable { await vm.loadFeed() }
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }

    // MARK: - Shared

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    FeedCardSkeleton()
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color.geckoBackground)
    }
}
