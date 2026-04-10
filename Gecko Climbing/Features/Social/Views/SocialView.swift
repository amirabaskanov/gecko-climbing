import SwiftUI

struct SocialView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: SocialViewModel?
    @State private var router = TabRouter<SocialRoute>()
    @State private var appeared = false

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
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: SocialRoute.self) { route in
                switch route {
                case .friendProfile(let uid):
                    FriendProfileView(uid: uid)
                case .followersList(let uid):
                    FollowersListView(uid: uid, mode: .followers)
                case .followingList(let uid):
                    FollowersListView(uid: uid, mode: .following)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SocialViewModel(
                    userRepository: appEnv.userRepository,
                    userId: authViewModel.currentUserId
                )
            }
            if let vm = viewModel {
                Task { await vm.loadFollowing() }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: SocialViewModel) -> some View {
        List {
            Section {
                UserSearchView(viewModel: vm)
                    .onChange(of: vm.searchQuery) { _, new in
                        vm.onSearchQueryChanged(new)
                    }
            }

            if vm.searchQuery.isEmpty {
                Section("Following (\(vm.following.count))") {
                    if vm.following.isEmpty {
                        EmptyStateView(
                            title: "No friends yet",
                            subtitle: "Search for climbers above to start following!"
                        )
                        .frame(height: 180)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(vm.following.enumerated()), id: \.element.id) { index, user in
                            NavigationLink(value: SocialRoute.friendProfile(uid: user.uid)) {
                                HStack(spacing: 12) {
                                    AvatarView(url: user.profileImageURL, size: 44, name: user.displayName)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.displayName).font(.subheadline.weight(.semibold))
                                        Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !user.highestGrade.isEmpty {
                                        GradeBadge(grade: user.highestGrade, isCompleted: true, size: .small)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .staggeredAppear(index: index, appeared: appeared)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 48)
        .searchable(text: Binding(get: { vm.searchQuery }, set: { vm.searchQuery = $0 }), prompt: "Search climbers...")
        .background(Color.geckoBackground)
        .refreshable { await vm.loadFollowing() }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}
