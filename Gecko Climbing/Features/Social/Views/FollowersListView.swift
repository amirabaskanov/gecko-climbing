import SwiftUI

struct FollowersListView: View {
    @Environment(AppEnvironment.self) private var appEnv
    let uid: String
    let mode: Mode

    enum Mode { case followers, following }

    @State private var users: [UserModel] = []
    @State private var isLoading = true

    var body: some View {
        content
            .background(Color.surfaceBackground)
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
                                if !user.highestGrade.isEmpty {
                                    GradeBadge(grade: user.highestGrade, isCompleted: true, size: .small)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary.opacity(0.5))
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
}
