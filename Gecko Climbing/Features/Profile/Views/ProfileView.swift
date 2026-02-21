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
            .navigationTitle("Profile")
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit")
                            .foregroundColor(Color.geckoGreen)
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
            VStack(spacing: 0) {
                // Profile header
                if let user = vm.user {
                    profileHeader(user)
                }

                Divider().padding(.vertical, 16)

                // Stats row
                if let user = vm.user {
                    statsRow(user)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    NavigationLink {
                        StatsView()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(Color.geckoGreen)
                            Text("View Full Stats")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .cardStyle(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Recent sessions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sessions")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    if vm.recentSessions.isEmpty {
                        EmptyStateView(
                            icon: "figure.climbing",
                            title: "No sessions yet",
                            subtitle: "Your sessions will appear here"
                        )
                        .frame(height: 160)
                    } else {
                        ForEach(vm.recentSessions) { session in
                            SessionRowView(session: session)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color.geckoBackground)
        .refreshable { await vm.load() }
    }

    private func profileHeader(_ user: UserModel) -> some View {
        VStack(spacing: 12) {
            AvatarView(url: user.profileImageURL, size: 88, name: user.displayName)
            Text(user.displayName)
                .font(.title2.weight(.bold))
            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            HStack(spacing: 32) {
                statPill(value: "\(user.followersCount)", label: "Followers")
                statPill(value: "\(user.followingCount)", label: "Following")
            }
        }
        .padding(.vertical, 20)
    }

    private func statsRow(_ user: UserModel) -> some View {
        HStack(spacing: 0) {
            statCard(value: "\(user.totalSessions)", label: "Sessions")
            Divider().frame(height: 40)
            statCard(value: user.highestGrade.isEmpty ? "—" : user.highestGrade,
                     label: "Top Grade",
                     valueColor: user.highestGrade.isEmpty ? .secondary : Color.gradeColor(for: user.highestGradeNumeric))
            Divider().frame(height: 40)
            statCard(value: "\(user.totalClimbs)", label: "Climbs")
        }
        .cardStyle(cornerRadius: 14)
    }

    private func statCard(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(valueColor)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .black, design: .rounded))
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}
