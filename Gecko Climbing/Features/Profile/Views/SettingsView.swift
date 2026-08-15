import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var isDeleting = false
    @State private var deleteError: Error?
    @State private var showFeedback = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Preferences

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Preferences")

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        settingsRowContent(
                            icon: "bell.badge",
                            title: "Notifications",
                            subtitle: "Manage push alerts",
                            iconColor: .geckoPrimary
                        )
                    }
                    .buttonStyle(.plain)
                    .bouncePress()
                }
                .staggeredAppear(index: 0, appeared: appeared)

                // MARK: - Privacy

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Privacy")

                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        settingsRowContent(
                            icon: "hand.raised",
                            title: "Blocked Users",
                            subtitle: "Manage who you've blocked",
                            iconColor: .geckoPrimary
                        )
                    }
                    .buttonStyle(.plain)
                    .bouncePress()
                }
                .staggeredAppear(index: 1, appeared: appeared)

                // MARK: - Support

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Support")

                    settingsRow(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "Send Feedback",
                        subtitle: "Report bugs or share ideas",
                        iconColor: .geckoPrimary
                    ) {
                        showFeedback = true
                    }

                    settingsRow(
                        icon: "sparkles",
                        title: "Replay the Guide",
                        subtitle: "Revisit the quick-start tour",
                        iconColor: .geckoPrimary
                    ) {
                        AnalyticsService.capture(.onboardingReplayed)
                        NotificationCenter.default.post(name: .replayOnboarding, object: nil)
                    }
                }
                .staggeredAppear(index: 2, appeared: appeared)

                // MARK: - Account

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Account")

                    settingsRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        subtitle: nil,
                        iconColor: .red
                    ) {
                        showSignOutConfirm = true
                    }

                    settingsRow(
                        icon: "trash",
                        title: "Delete Account",
                        subtitle: "Permanently erase your account and data",
                        iconColor: .red
                    ) {
                        showDeleteConfirm = true
                    }
                    .disabled(isDeleting)
                }
                .staggeredAppear(index: 3, appeared: appeared)

                // MARK: - About

                VStack(spacing: 16) {
                    sectionHeader("About")

                    VStack(spacing: 0) {
                        aboutRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        Divider().padding(.horizontal, 16)
                        aboutRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    }
                    .cardStyle()

                    HStack(spacing: 8) {
                        GeckoLogoView(size: 24, color: .geckoPrimary)
                        Text("Gecko Climbing")
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(Color.geckoPrimary)
                    }
                    .padding(.top, 4)
                }
                .staggeredAppear(index: 4, appeared: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.geckoBackground)
        .navigationTitle("Settings")
        .onAppear { appeared = true }
        .overlay {
            if isDeleting {
                deletingOverlay
            }
        }
        .confirmationDialog("Sign out of Gecko Climbing?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, posts, sessions, and stats. This can't be undone.")
        }
        .alert("Confirm your password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $passwordInput)
                .textContentType(.password)
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount(reauthPassword: passwordInput) }
            }
            Button("Cancel", role: .cancel) { passwordInput = "" }
        } message: {
            Text("For your security, please re-enter your password to permanently delete your account.")
        }
        .errorAlert(error: $deleteError)
        .sheet(isPresented: $showFeedback) {
            FeedbackView(viewModel: FeedbackViewModel(
                feedbackRepository: appEnvironment.feedbackRepository,
                userId: authViewModel.currentUserId
            ))
        }
    }

    // MARK: - Account deletion

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Deleting your account…")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .transition(.opacity)
    }

    private func deleteAccount(reauthPassword: String? = nil) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await authViewModel.deleteAccount(
                userRepository: appEnvironment.userRepository,
                reauthPassword: reauthPassword
            )
            // On success the auth state listener flips the app back to sign-in;
            // no further navigation needed here.
            passwordInput = ""
        } catch let authError as AuthError {
            if case .passwordRequired = authError {
                // Password account that needs re-auth — prompt and retry.
                passwordInput = ""
                showPasswordPrompt = true
            } else {
                deleteError = authError
            }
        } catch {
            deleteError = error
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String?,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsRowContent(
                icon: icon,
                title: title,
                subtitle: subtitle,
                iconColor: iconColor
            )
        }
        .bouncePress()
    }

    private func settingsRowContent(
        icon: String,
        title: String,
        subtitle: String?,
        iconColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(iconColor == .red ? .red : .primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(14)
        .cardStyle()
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .fontDesign(.rounded)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Blocked Users
//
// Colocated with Settings (instead of its own file) so it ships in the Xcode
// build target without a project-file edit. App Store Review reaches this
// surface via Settings → Privacy → Blocked Users to verify Guideline 1.2.

/// Management screen for the current user's block list. State lives in-view
/// — the logic is a fetch and an unblock-with-rollback, anything more
/// elaborate would be the same shape with extra ceremony.
struct BlockedUsersView: View {
    @Environment(AppEnvironment.self) private var appEnv

    @State private var users: [UserModel] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if users.isEmpty {
                emptyState
            } else {
                listState
            }
        }
        .background(Color.geckoBackground)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .errorAlert(error: $error)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(Color.geckoPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "hand.raised")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.geckoSecondaryText.opacity(0.5))
            Text("No blocked users")
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
            Text("You can block someone from\nthe \"…\" menu on any post.")
                .font(.subheadline)
                .foregroundStyle(Color.geckoSecondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private var listState: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(users, id: \.uid) { user in
                    blockedRow(user)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private func blockedRow(_ user: UserModel) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.profileImageURL, size: 44, name: user.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(Color.geckoSecondaryText)
            }

            Spacer()

            Button {
                Task { await unblock(user) }
            } label: {
                Text("Unblock")
                    .font(.caption.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.geckoPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.geckoInputBackground)
                    )
            }
            .buttonStyle(.plain)
            .bouncePress()
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await appEnv.userRepository.fetchBlockedUsers()
        } catch {
            self.error = error
        }
    }

    private func unblock(_ user: UserModel) async {
        let originalIndex = users.firstIndex(where: { $0.uid == user.uid })
        withAnimation(.geckoSnappy) {
            users.removeAll { $0.uid == user.uid }
        }
        do {
            try await appEnv.userRepository.unblockUser(user.uid)
            AnalyticsService.capture(.userUnblocked)
        } catch {
            if let idx = originalIndex {
                withAnimation(.geckoSnappy) {
                    users.insert(user, at: min(idx, users.count))
                }
            }
            self.error = error
        }
    }
}
