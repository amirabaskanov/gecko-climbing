import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var showSignOutConfirm = false
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
                }
                .staggeredAppear(index: 1, appeared: appeared)

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
                }
                .staggeredAppear(index: 2, appeared: appeared)

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
                .staggeredAppear(index: 3, appeared: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.geckoBackground)
        .navigationTitle("Settings")
        .onAppear { appeared = true }
        .confirmationDialog("Sign out of Gecko Climbing?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(viewModel: FeedbackViewModel(
                feedbackRepository: appEnvironment.feedbackRepository,
                userId: authViewModel.currentUserId
            ))
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
