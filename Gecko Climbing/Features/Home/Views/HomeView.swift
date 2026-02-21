import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: HomeViewModel?
    @State private var router = TabRouter<HomeRoute>()

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
            .navigationTitle("Feed")
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                viewModel = vm
                Task { await vm.loadFeed() }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                ProgressView("Loading feed...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.posts.isEmpty {
                EmptyStateView(
                    icon: "person.2.fill",
                    title: "Your feed is empty",
                    subtitle: "Follow friends to see their sessions here"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.posts) { post in
                            FeedCardView(
                                post: post,
                                onLike: { Task { await vm.toggleLike(post) } },
                                onUserTap: { router.push(.friendProfile(uid: post.userId)) }
                            )
                            .onTapGesture {
                                router.push(.postDetail(postId: post.postId))
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color.geckoBackground)
                .refreshable { await vm.loadFeed() }
            }
        }
        .background(Color.geckoBackground)
    }
}
