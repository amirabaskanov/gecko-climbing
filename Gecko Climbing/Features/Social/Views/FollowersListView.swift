import SwiftUI

/// Followers and following for one account, switchable in place so the
/// reader never has to pop back to flip between the two lists.
struct FollowersListView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    let uid: String
    let mode: Mode

    enum Mode: Hashable, CaseIterable {
        case followers, following

        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }

    @State private var selection: Mode
    @State private var owner: UserModel?
    @State private var followers: [UserModel]?
    @State private var following: [UserModel]?
    @State private var viewerFollowingIds: Set<String> = []
    @State private var error: Error?

    init(uid: String, mode: Mode) {
        self.uid = uid
        self.mode = mode
        _selection = State(initialValue: mode)
    }

    private var users: [UserModel]? {
        selection == .followers ? followers : following
    }

    var body: some View {
        VStack(spacing: 0) {
            UnderlineTabSwitcher(items: Mode.allCases, title: \.title, selection: $selection)
            list
        }
        .tabBarScrollInset()
        .background(Color.geckoBackground)
        .navigationTitle(owner.map { "@\($0.username)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(error: $error)
        .task {
            async let ownerTask = try? appEnv.userRepository.fetchUser(uid: uid)
            // The VIEWER's follow set, so rows can offer follow-back even when
            // this is someone else's list.
            async let idsTask = try? appEnv.userRepository.fetchFollowingIds(uid: authViewModel.currentUserId)
            owner = await ownerTask
            viewerFollowingIds = (await idsTask) ?? []
        }
        .task(id: selection) {
            await loadList(selection)
        }
    }

    @ViewBuilder
    private var list: some View {
        if let users {
            if users.isEmpty {
                VStack(spacing: 6) {
                    Text(selection == .followers ? "No followers yet" : "Not following anyone yet")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(selection == .followers
                         ? "Climbers who follow this account show up here."
                         : "Accounts this climber follows show up here.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.geckoSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
                .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users, id: \.uid) { user in
                            row(user)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func row(_ user: UserModel) -> some View {
        if user.uid == authViewModel.currentUserId {
            // The viewer's own row: no link, no follow button, no dimming.
            rowContent(user, trailing: AnyView(
                Text("You")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.geckoSecondaryText)
            ))
        } else {
            // View-based link: this list is reachable from every tab's stack.
            NavigationLink {
                FriendProfileView(uid: user.uid)
            } label: {
                rowContent(user, trailing: AnyView(
                    FollowButton(isFollowing: viewerFollowingIds.contains(user.uid), displayName: user.displayName) {
                        Task { await toggleFollow(user) }
                    }
                ))
            }
            .buttonStyle(.plain)
        }
    }

    private func rowContent(_ user: UserModel, trailing: AnyView) -> some View {
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
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Data

    private func loadList(_ mode: Mode) async {
        switch mode {
        case .followers where followers != nil, .following where following != nil:
            return
        default:
            break
        }
        do {
            switch mode {
            case .followers:
                followers = try await appEnv.userRepository.fetchFollowers(uid: uid)
            case .following:
                following = try await appEnv.userRepository.fetchFollowing(uid: uid)
            }
        } catch {
            self.error = error
            if mode == .followers { followers = [] } else { following = [] }
        }
    }

    private func toggleFollow(_ user: UserModel) async {
        let wasFollowing = viewerFollowingIds.contains(user.uid)
        if wasFollowing {
            viewerFollowingIds.remove(user.uid)
        } else {
            viewerFollowingIds.insert(user.uid)
        }
        do {
            if wasFollowing {
                try await appEnv.userRepository.unfollow(targetUID: user.uid)
            } else {
                try await appEnv.userRepository.follow(targetUID: user.uid)
            }
        } catch {
            if wasFollowing {
                viewerFollowingIds.insert(user.uid)
            } else {
                viewerFollowingIds.remove(user.uid)
            }
            self.error = error
        }
    }
}
