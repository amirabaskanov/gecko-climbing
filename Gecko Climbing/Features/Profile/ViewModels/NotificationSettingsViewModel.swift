import Foundation
import Observation

@Observable @MainActor
final class NotificationSettingsViewModel {
    var prefs: NotificationPrefs = .default
    var isLoading = false
    var error: Error?

    private let userRepository: any UserRepositoryProtocol
    private let userId: String
    private var loaded = false

    init(userRepository: any UserRepositoryProtocol, userId: String) {
        self.userRepository = userRepository
        self.userId = userId
    }

    func load() async {
        guard !loaded else { return }
        isLoading = true
        do {
            prefs = try await userRepository.fetchNotificationPrefs(for: userId)
            loaded = true
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func updateSocial(_ value: Bool) async {
        var next = prefs
        next.social = value
        await persist(next)
    }

    func updateFriends(_ value: Bool) async {
        var next = prefs
        next.friends = value
        await persist(next)
    }

    func updateReminders(_ value: Bool) async {
        var next = prefs
        next.reminders = value
        await persist(next)
    }

    func updateFriendPosts(_ value: Bool) async {
        var next = prefs
        next.friendPosts = value
        await persist(next)
    }

    func setAll(_ value: Bool) async {
        await persist(NotificationPrefs(
            social: value,
            friends: value,
            reminders: value,
            friendPosts: value ? prefs.friendPosts : false
        ))
    }

    var masterEnabled: Bool {
        prefs.social || prefs.friends || prefs.reminders
    }

    private func persist(_ next: NotificationPrefs) async {
        let previous = prefs
        prefs = next
        do {
            try await userRepository.updateNotificationPrefs(next, for: userId)
        } catch {
            prefs = previous
            self.error = error
        }
    }
}
