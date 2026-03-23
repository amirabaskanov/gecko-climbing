import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: ProfileViewModel?
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.headline.weight(.bold))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.geckoPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.geckoPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            if let vm = viewModel {
                EditProfileView(viewModel: vm)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = ProfileViewModel(
                    userRepository: appEnv.userRepository,
                    sessionRepository: appEnv.sessionRepository,
                    storageRepository: appEnv.storageRepository,
                    userId: authViewModel.currentUserId
                )
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: ProfileViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = vm.user {
                    // MARK: - Header
                    profileHeader(user)

                    // MARK: - Stats
                    statsSection(vm, user: user)
                        .padding(.horizontal, 16)

                    // MARK: - Recent Sessions
                    sessionsSection(vm)
                }
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.bottom, 48)
        .background(Color.surfaceBackground)
        .refreshable { await vm.load() }
    }

    // MARK: - Profile Header

    private func profileHeader(_ user: UserModel) -> some View {
        VStack(spacing: 12) {
            AvatarView(url: user.profileImageURL, size: 80, name: user.displayName)

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title3.weight(.bold))
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 24) {
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
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Stats

    private func statsSection(_ vm: ProfileViewModel, user: UserModel) -> some View {
        NavigationLink {
            StatsView()
        } label: {
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    statItem(
                        value: "\(user.totalSessions)",
                        label: "Sessions"
                    )
                    Divider().frame(height: 32).opacity(0.3)
                    statItem(
                        value: user.highestGrade.isEmpty ? "—" : user.highestGrade,
                        label: "Top Grade"
                    )
                    Divider().frame(height: 32).opacity(0.3)
                    statItem(
                        value: "\(user.totalClimbs)",
                        label: "Climbs"
                    )
                }

                if vm.weeklyStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(Color.geckoFlashGold)
                        Text("\(vm.weeklyStreak) week streak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Text("View Full Stats")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.geckoPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.geckoPrimary)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .bouncePress()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sessions

    private func sessionsSection(_ vm: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !vm.recentSessions.isEmpty {
                    NavigationLink {
                        SessionListView(refreshToken: UUID())
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.geckoPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)

            if vm.recentSessions.isEmpty {
                EmptyStateView(
                    title: "No sessions yet",
                    subtitle: "Your sessions will appear here"
                )
                .frame(height: 160)
            } else {
                ForEach(vm.recentSessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Components

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
