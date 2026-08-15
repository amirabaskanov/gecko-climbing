import Foundation
import Observation

@Observable @MainActor
final class SocialViewModel {
    var searchQuery = ""
    var searchResults: [UserModel] = []
    var isSearching = false
    var following: [UserModel] = []
    /// Complete follow-state set backing isFollowing. The `following` array is
    /// only the display list (capped server-side) — deriving button state from
    /// it shows stale "Follow" buttons past the cap, which then silently no-op.
    private var followingIds: Set<String> = []
    var error: Error?

    private let userRepository: any UserRepositoryProtocol
    private let userId: String
    private var searchTask: Task<Void, Never>?

    init(userRepository: any UserRepositoryProtocol, userId: String) {
        self.userRepository = userRepository
        self.userId = userId
    }

    func loadFollowing() async {
        do {
            async let listTask = userRepository.fetchFollowing(uid: userId)
            async let idsTask = userRepository.fetchFollowingIds(uid: userId)
            let (list, ids) = try await (listTask, idsTask)
            following = list
            followingIds = ids
        } catch {
            self.error = error
        }
    }

    func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // debounce
            guard !Task.isCancelled else { return }
            do {
                searchResults = try await userRepository.searchUsers(query: query)
            } catch {
                if !Task.isCancelled { self.error = error }
            }
            isSearching = false
        }
    }

    func follow(user: UserModel) async {
        let wasFollowing = followingIds.contains(user.uid)
        followingIds.insert(user.uid)
        do {
            try await userRepository.follow(targetUID: user.uid)
            if !following.contains(where: { $0.uid == user.uid }) {
                following.append(user)
            }
        } catch {
            if !wasFollowing { followingIds.remove(user.uid) }
            self.error = error
        }
    }

    func unfollow(user: UserModel) async {
        let wasFollowing = followingIds.contains(user.uid)
        followingIds.remove(user.uid)
        do {
            try await userRepository.unfollow(targetUID: user.uid)
            following.removeAll { $0.uid == user.uid }
        } catch {
            if wasFollowing { followingIds.insert(user.uid) }
            self.error = error
        }
    }

    func isFollowing(_ uid: String) -> Bool {
        followingIds.contains(uid)
    }
}
