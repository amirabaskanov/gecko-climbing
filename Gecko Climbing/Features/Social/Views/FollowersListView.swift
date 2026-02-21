import SwiftUI

struct FollowersListView: View {
    @Environment(AppEnvironment.self) private var appEnv
    let uid: String
    let mode: Mode

    enum Mode { case followers, following }

    @State private var users: [UserModel] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                EmptyStateView(icon: "person.2", title: "No \(mode == .followers ? "followers" : "following") yet", subtitle: "")
            } else {
                List(users) { user in
                    NavigationLink(value: SocialRoute.friendProfile(uid: user.uid)) {
                        HStack(spacing: 12) {
                            AvatarView(url: user.profileImageURL, size: 44, name: user.displayName)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.subheadline.weight(.semibold))
                                Text("@\(user.username)").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if !user.highestGrade.isEmpty {
                                GradeBadge(grade: user.highestGrade, isCompleted: true, size: .small)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(mode == .followers ? "Followers" : "Following")
        .task {
            do {
                if mode == .followers {
                    users = try await appEnv.userRepository.fetchFollowers(uid: uid)
                } else {
                    users = try await appEnv.userRepository.fetchFollowing(uid: uid)
                }
            } catch {}
            isLoading = false
        }
    }
}
