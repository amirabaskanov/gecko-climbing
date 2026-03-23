import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: HomeViewModel?
    @State private var router = TabRouter<HomeRoute>()
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surfaceBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    GeckoLogoView(size: 28, color: .geckoPrimary, showWordmark: true)
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .postDetail(let postId):
                    if let post = viewModel?.posts.first(where: { $0.postId == postId }) {
                        PostDetailView(post: post)
                    }
                case .friendProfile(let uid):
                    FriendProfileView(uid: uid)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = HomeViewModel(postRepository: appEnv.postRepository, userId: authViewModel.currentUserId)
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
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            FeedCardSkeleton()
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color.surfaceBackground)
            } else if vm.posts.isEmpty {
                ScrollView {
                    EmptyStateView(
                        
                        title: "Your feed is empty",
                        subtitle: "Follow friends to see their sessions here"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
                .refreshable { await vm.loadFeed() }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(vm.posts.enumerated()), id: \.element.id) { index, post in
                            FeedCardView(
                                post: post,
                                currentUserId: authViewModel.currentUserId,
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
                .background(Color.surfaceBackground)
                .refreshable { await vm.loadFeed() }
                .onAppear {
                    withAnimation { appeared = true }
                }
            }
        }
        .background(Color.surfaceBackground)
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 })) {
            Task { await vm.loadFeed() }
        }
    }
}
