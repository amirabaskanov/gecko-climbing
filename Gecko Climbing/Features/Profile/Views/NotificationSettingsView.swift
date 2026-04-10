import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.openURL) private var openURL

    @State private var viewModel: NotificationSettingsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.geckoBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = NotificationSettingsViewModel(
                    userRepository: appEnv.userRepository,
                    userId: authViewModel.currentUserId
                )
                viewModel = vm
                await vm.load()
            }
            await notificationService.refreshAuthorizationStatus()
        }
    }

    @ViewBuilder
    private func content(_ vm: NotificationSettingsViewModel) -> some View {
        @Bindable var bindableVM = vm
        ScrollView {
            VStack(spacing: 20) {
                if !systemNotificationsEnabled {
                    systemDisabledBanner
                }

                masterToggleCard(vm)

                categoryCard(vm)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .errorAlert(error: $bindableVM.error)
    }

    private var systemNotificationsEnabled: Bool {
        let status = notificationService.authorizationStatus
        return status == .authorized || status == .provisional
    }

    private var systemDisabledBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.geckoPrimary)
                .frame(width: 36, height: 36)
                .background(Color.geckoPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off in Settings")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                Text("Turn them on to get updates from Gecko.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.geckoPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .cardStyle()
    }

    private func masterToggleCard(_ vm: NotificationSettingsViewModel) -> some View {
        let binding = Binding<Bool>(
            get: { vm.masterEnabled },
            set: { newValue in
                Task {
                    await vm.setAll(newValue)
                    await notificationService.refreshScheduledNotifications()
                }
            }
        )
        return Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Push notifications")
                    .font(.body.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                Text("Master switch for all Gecko alerts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.geckoPrimary)
        .padding(14)
        .cardStyle()
    }

    private func categoryCard(_ vm: NotificationSettingsViewModel) -> some View {
        VStack(spacing: 0) {
            categoryRow(
                title: "Social",
                subtitle: "Follows, likes, comments, and mentions",
                isOn: Binding(
                    get: { vm.prefs.social },
                    set: { newValue in Task { await vm.updateSocial(newValue) } }
                )
            )
            Divider().padding(.leading, 14)
            categoryRow(
                title: "Friends",
                subtitle: "New PRs from people you follow",
                isOn: Binding(
                    get: { vm.prefs.friends },
                    set: { newValue in Task { await vm.updateFriends(newValue) } }
                )
            )
            Divider().padding(.leading, 38)
            subCategoryRow(
                title: "Friend posts",
                subtitle: "When friends share a new session",
                isOn: Binding(
                    get: { vm.prefs.friendPosts },
                    set: { newValue in Task { await vm.updateFriendPosts(newValue) } }
                ),
                enabled: vm.prefs.friends
            )
            Divider().padding(.leading, 14)
            categoryRow(
                title: "Reminders",
                subtitle: "Weekly recap and comeback nudges",
                isOn: Binding(
                    get: { vm.prefs.reminders },
                    set: { newValue in
                        Task {
                            await vm.updateReminders(newValue)
                            await notificationService.refreshScheduledNotifications()
                        }
                    }
                )
            )
        }
        .cardStyle()
    }

    private func categoryRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.geckoPrimary)
        .padding(14)
    }

    private func subCategoryRow(title: String, subtitle: String, isOn: Binding<Bool>, enabled: Bool) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(enabled ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.geckoPrimary)
        .padding(.vertical, 12)
        .padding(.leading, 38)
        .padding(.trailing, 14)
        .disabled(!enabled)
    }
}
