import SwiftUI

struct SocialView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Bindable var router: TabRouter<SocialRoute>
    @State private var viewModel: SocialViewModel?
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
        .errorAlert(error: Binding(
            get: { viewModel?.error },
            set: { viewModel?.error = $0 }
        ))
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
                // Discovery lives here now — reason-labeled suggestions from
                // the scoring engine, not a global leaderboard.
                if !vm.suggestions.isEmpty {
                    Section {
                        ForEach(Array(vm.suggestions.prefix(5).enumerated()), id: \.element.id) { index, suggestion in
                            suggestionRow(suggestion, vm: vm)
                                .staggeredAppear(index: index, appeared: appeared)
                        }
                    } header: {
                        Text("FIND YOUR CREW")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(Color.geckoPrimary)
                    }
                }

                Section("Following (\(vm.following.count))") {
                    if vm.following.isEmpty {
                        EmptyStateView(
                            title: "No friends yet",
                            subtitle: "Follow climbers above to fill your feed"
                        )
                        .frame(height: 140)
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
        .searchable(
            text: Binding(get: { vm.searchQuery }, set: { vm.searchQuery = $0 }),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search climbers..."
        )
        .background(Color.geckoBackground)
        .refreshable { await vm.loadFollowing() }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Suggestion Row

    private func suggestionRow(_ suggestion: ScoredSuggestion, vm: SocialViewModel) -> some View {
        let user = suggestion.user
        let following = vm.isFollowing(user.uid)

        return NavigationLink(value: SocialRoute.friendProfile(uid: user.uid)) {
            HStack(spacing: 12) {
                AvatarView(url: user.profileImageURL, size: 44, name: user.displayName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(suggestion.reason.label)
                        .font(.caption)
                        .foregroundStyle(Color.geckoPrimary)
                        .lineLimit(1)
                }
                Spacer()

                Button {
                    Task {
                        if following {
                            await vm.unfollow(user: user)
                        } else {
                            await vm.follow(user: user)
                        }
                    }
                } label: {
                    Text(following ? "Following" : "Follow")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            following ? AnyShapeStyle(Color.geckoInputBackground) : AnyShapeStyle(Color.geckoPrimary)
                        )
                        .foregroundStyle(following ? Color.primary : Color.geckoOnPrimary)
                        .overlay(
                            Capsule().stroke(Color.geckoDivider, lineWidth: following ? 1 : 0)
                        )
                        .clipShape(Capsule())
                }
                // .borderless keeps the button's hit-testing its own inside
                // the row's NavigationLink.
                .buttonStyle(.borderless)
                .accessibilityLabel(following ? "Unfollow \(user.displayName)" : "Follow \(user.displayName)")
            }
            .padding(.vertical, 4)
        }
    }
}
