import SwiftUI

struct FollowersListView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    let uid: String
    let mode: Mode

    enum Mode { case followers, following }

    @State private var users: [UserModel] = []
    @State private var viewerFollowingIds: Set<String> = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        content
            .background(Color.geckoBackground)
        .navigationTitle(mode == .followers ? "Followers" : "Following")
        .errorAlert(error: $error)
        .task {
            do {
                async let listTask = mode == .followers
                    ? appEnv.userRepository.fetchFollowers(uid: uid)
                    : appEnv.userRepository.fetchFollowing(uid: uid)
                // The VIEWER's follow set, so rows can offer follow-back —
                // this list may be someone else's followers.
                async let idsTask = appEnv.userRepository.fetchFollowingIds(uid: authViewModel.currentUserId)
                users = try await listTask
                viewerFollowingIds = (try? await idsTask) ?? []
            } catch {
                self.error = error
            }
            isLoading = false
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

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if users.isEmpty {
            EmptyStateView(title: "No \(mode == .followers ? "followers" : "following") yet", subtitle: "")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(users, id: \.uid) { user in
                        NavigationLink {
                            FriendProfileView(uid: user.uid)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: user.profileImageURL, size: 44, name: user.displayName)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName).font(.subheadline.weight(.semibold))
                                    Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()

                                if user.uid != authViewModel.currentUserId {
                                    followButton(user)
                                } else if !user.highestGrade.isEmpty {
                                    GradeBadge(grade: user.highestGrade, isCompleted: true, size: .small)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if user.uid != users.last?.uid {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
            }
        }
    }

    private func followButton(_ user: UserModel) -> some View {
        let following = viewerFollowingIds.contains(user.uid)
        return Button {
            Task { await toggleFollow(user) }
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
        // .borderless keeps this button's hit-testing its own inside the row link.
        .buttonStyle(.borderless)
        .accessibilityLabel(following ? "Unfollow \(user.displayName)" : "Follow \(user.displayName)")
    }
}
