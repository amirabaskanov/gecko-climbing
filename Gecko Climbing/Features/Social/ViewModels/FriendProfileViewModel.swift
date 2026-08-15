import Foundation
import Observation

@Observable @MainActor
final class FriendProfileViewModel {
    var user: UserModel?
    var sessions: [SessionModel] = []
    var isFollowing = false
    var isLoading = false
    var error: Error?
    /// Sessions are secondary content — if their fetch fails (e.g. a missing
    /// Firestore index) the profile and Follow button must still work.
    var sessionsUnavailable = false

    private let uid: String
    private let userRepository: any UserRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    var onFollowChanged: ((Bool) -> Void)?

    init(uid: String, userRepository: any UserRepositoryProtocol, sessionRepository: any SessionRepositoryProtocol, onFollowChanged: ((Bool) -> Void)? = nil) {
        self.uid = uid
        self.userRepository = userRepository
        self.sessionRepository = sessionRepository
        self.onFollowChanged = onFollowChanged
    }

    func load() async {
        isLoading = true
        async let userTask = userRepository.fetchUser(uid: uid)
        async let followingTask = userRepository.isFollowing(targetUID: uid)

        do {
            let (u, f) = try await (userTask, followingTask)
            user = u
            isFollowing = f
        } catch {
            self.error = error
            isLoading = false
            return
        }

        await loadSessions()
        isLoading = false
    }

    func loadSessions() async {
        do {
            sessions = try await sessionRepository.fetchSessions(for: uid)
            sessionsUnavailable = false
        } catch {
            sessionsUnavailable = true
        }
    }

    func toggleFollow() async {
        guard user != nil else { return }
        do {
            if isFollowing {
                try await userRepository.unfollow(targetUID: uid)
                self.user?.followersCount = max(0, (self.user?.followersCount ?? 0) - 1)
            } else {
                try await userRepository.follow(targetUID: uid)
                self.user?.followersCount = (self.user?.followersCount ?? 0) + 1
            }
            isFollowing.toggle()
            onFollowChanged?(isFollowing)
        } catch {
            self.error = error
        }
    }
}
