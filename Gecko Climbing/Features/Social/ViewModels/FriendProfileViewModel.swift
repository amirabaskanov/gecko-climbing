import Foundation
import Observation

@Observable
final class FriendProfileViewModel {
    var user: UserModel?
    var sessions: [SessionModel] = []
    var isFollowing = false
    var isLoading = false
    var error: Error?

    private let uid: String
    private let userRepository: any UserRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol

    init(uid: String, userRepository: any UserRepositoryProtocol, sessionRepository: any SessionRepositoryProtocol) {
        self.uid = uid
        self.userRepository = userRepository
        self.sessionRepository = sessionRepository
    }

    func load() async {
        isLoading = true
        async let userTask = userRepository.fetchUser(uid: uid)
        async let sessionsTask = sessionRepository.fetchSessions(for: uid)
        async let followingTask = userRepository.isFollowing(targetUID: uid)

        do {
            let (u, s, f) = try await (userTask, sessionsTask, followingTask)
            user = u
            sessions = s
            isFollowing = f
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func toggleFollow() async {
        guard let user else { return }
        do {
            if isFollowing {
                try await userRepository.unfollow(targetUID: uid)
                self.user?.followersCount = max(0, (self.user?.followersCount ?? 0) - 1)
            } else {
                try await userRepository.follow(targetUID: uid)
                self.user?.followersCount = (self.user?.followersCount ?? 0) + 1
            }
            isFollowing.toggle()
            _ = user
        } catch {
            self.error = error
        }
    }
}
