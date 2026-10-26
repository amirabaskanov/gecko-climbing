import SwiftUI

/// The Crew tab. Three things, in the order a climber wants them: who in
/// their crew climbed this week (presence strip), who they should add
/// (suggestion cards), and the crew itself (rows with last-session copy).
/// Search sits in the navigation bar and swaps the whole body for results.
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
                        .background(Color.geckoBackground)
                }
            }
            .navigationTitle("Crew")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
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
                    postRepository: appEnv.postRepository,
                    userId: authViewModel.currentUserId
                )
            }
            if let vm = viewModel {
                Task { await vm.loadFollowing() }
            }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func content(_ vm: SocialViewModel) -> some View {
        @Bindable var vm = vm

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if !vm.searchQuery.isEmpty {
                    searchResults(vm)
                } else {
                    if !vm.activeThisWeek.isEmpty {
                        thisWeekStrip(vm)
                    }
                    if !vm.suggestions.isEmpty {
                        findYourCrew(vm)
                    }
                    yourCrew(vm)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .tabBarScrollInset()
        .background(Color.geckoBackground)
        .searchable(
            text: $vm.searchQuery,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search climbers"
        )
        .onChange(of: vm.searchQuery) { _, new in
            vm.onSearchQueryChanged(new)
        }
        .refreshable { await vm.loadFollowing() }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Climbing this week

    private func thisWeekStrip(_ vm: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SocialSectionHeader(title: "Climbing this week")

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(vm.activeThisWeek, id: \.uid) { user in
                        let activity = vm.activity[user.uid]
                        Button {
                            router.push(.friendProfile(uid: user.uid))
                        } label: {
                            VStack(spacing: 6) {
                                AvatarView(
                                    url: user.profileImageURL,
                                    size: 62,
                                    name: user.displayName,
                                    gradeNumeric: user.highestGradeNumeric,
                                    ring: Color.gradeColor(for: activity?.topGradeNumeric ?? user.highestGradeNumeric)
                                )
                                Text(user.displayName.firstWord)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(activity?.lastPostedAt.crewRecency ?? "")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.geckoSecondaryText)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(user.displayName), climbed \(activity?.lastPostedAt.crewRecencySentence ?? "recently")")
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Find your crew

    private func findYourCrew(_ vm: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SocialSectionHeader(title: "Find your crew")

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(vm.suggestions) { suggestion in
                        let user = suggestion.user
                        ClimberSuggestionCard(
                            user: user,
                            reason: suggestion.reason,
                            isFollowing: vm.isFollowing(user.uid),
                            onToggleFollow: {
                                Task {
                                    if vm.isFollowing(user.uid) {
                                        await vm.unfollow(user: user)
                                    } else {
                                        await vm.follow(user: user)
                                    }
                                }
                            },
                            onTap: { router.push(.friendProfile(uid: user.uid)) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    // MARK: - Your crew

    @ViewBuilder
    private func yourCrew(_ vm: SocialViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SocialSectionHeader(
                title: "Your crew",
                detail: vm.following.isEmpty ? nil : "\(vm.following.count)"
            )
            .padding(.bottom, 6)

            if vm.following.isEmpty {
                emptyCrew
            } else {
                ForEach(Array(vm.crew.enumerated()), id: \.element.uid) { index, user in
                    crewRow(user, activity: vm.activity[user.uid])
                        .staggeredAppear(index: index, appeared: appeared)
                }
            }
        }
    }

    private func crewRow(_ user: UserModel, activity: CrewActivity?) -> some View {
        let recent = activity?.isRecent() ?? false
        return Button {
            router.push(.friendProfile(uid: user.uid))
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    url: user.profileImageURL,
                    size: 50,
                    name: user.displayName,
                    gradeNumeric: user.highestGradeNumeric,
                    ring: recent ? Color.gradeColor(for: activity?.topGradeNumeric ?? user.highestGradeNumeric) : .clear
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(crewMeta(user, activity: activity))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.geckoSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if user.highestGradeNumeric >= 0 && !user.highestGrade.isEmpty {
                    GradeTag(gradeNumeric: user.highestGradeNumeric, size: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(user.displayName), \(crewMeta(user, activity: activity))")
    }

    /// One line that says what the climber has been up to. Falls back to the
    /// handle when the feed has nothing from them yet.
    private func crewMeta(_ user: UserModel, activity: CrewActivity?) -> String {
        guard let activity else { return "@\(user.username)" }
        let gym = activity.gymName.trimmedGymName
        if gym.isEmpty {
            return "Climbed \(activity.lastPostedAt.crewRecencySentence)"
        }
        return "Climbed \(activity.lastPostedAt.crewRecencySentence) at \(gym)"
    }

    private var emptyCrew: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nobody here yet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text("Follow a few climbers and their sessions start showing up in your feed.")
                .font(.system(size: 14))
                .foregroundStyle(Color.geckoSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.geckoCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.geckoDivider, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Search

    @ViewBuilder
    private func searchResults(_ vm: SocialViewModel) -> some View {
        if vm.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if vm.searchResults.isEmpty {
            VStack(spacing: 6) {
                Text("No climbers found")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("Try a different name or username.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.geckoSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(vm.searchResults, id: \.uid) { user in
                    searchRow(user, vm: vm)
                }
            }
            .padding(.top, 4)
        }
    }

    private func searchRow(_ user: UserModel, vm: SocialViewModel) -> some View {
        Button {
            router.push(.friendProfile(uid: user.uid))
        } label: {
            HStack(spacing: 12) {
                AvatarView(url: user.profileImageURL, size: 48, name: user.displayName, gradeNumeric: user.highestGradeNumeric)
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("@\(user.username)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.geckoSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                FollowButton(isFollowing: vm.isFollowing(user.uid), displayName: user.displayName) {
                    Task {
                        if vm.isFollowing(user.uid) {
                            await vm.unfollow(user: user)
                        } else {
                            await vm.follow(user: user)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var firstWord: String {
        split(separator: " ").first.map(String.init) ?? self
    }
}
