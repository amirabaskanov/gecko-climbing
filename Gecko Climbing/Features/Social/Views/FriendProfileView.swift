import SwiftUI

struct FriendProfileView: View {
    @Environment(AppEnvironment.self) private var appEnv
    let uid: String

    @State private var viewModel: FriendProfileViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = FriendProfileViewModel(
                    uid: uid,
                    userRepository: appEnv.userRepository,
                    sessionRepository: appEnv.sessionRepository
                )
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: FriendProfileViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if let user = vm.user {
                    profileHeader(user, vm: vm)
                }

                Divider().padding(.vertical, 16)

                // Sessions
                if vm.sessions.isEmpty {
                    EmptyStateView(
                        
                        title: "No sessions shared yet",
                        subtitle: ""
                    )
                    .frame(height: 160)
                } else {
                    VStack(spacing: 10) {
                        ForEach(vm.sessions.prefix(10)) { session in
                            SessionRowView(session: session)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.surfaceBackground)
        .navigationTitle(vm.user?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
    }

    private func profileHeader(_ user: UserModel, vm: FriendProfileViewModel) -> some View {
        VStack(spacing: 12) {
            AvatarView(url: user.profileImageURL, size: 80, name: user.displayName)
            Text(user.displayName)
                .font(.title2.weight(.bold))
            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 32) {
                NavigationLink {
                    FollowersListView(uid: user.uid, mode: .followers)
                } label: {
                    statPill(value: "\(user.followersCount)", label: "Followers")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FollowersListView(uid: user.uid, mode: .following)
                } label: {
                    statPill(value: "\(user.followingCount)", label: "Following")
                }
                .buttonStyle(.plain)

                statPill(value: user.highestGrade.isEmpty ? "—" : user.highestGrade, label: "Top Grade")
            }

            Button {
                Task { await vm.toggleFollow() }
            } label: {
                Text(vm.isFollowing ? "Following" : "Follow")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 140)
                    .padding(.vertical, 10)
                    .background(vm.isFollowing ? Color.gray.opacity(0.15) : Color.geckoPrimary)
                    .foregroundStyle(vm.isFollowing ? Color.primary : Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
