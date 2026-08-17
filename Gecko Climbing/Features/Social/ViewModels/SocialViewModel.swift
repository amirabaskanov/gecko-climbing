import Foundation
import Observation

@Observable @MainActor
final class SocialViewModel {
    var searchQuery = ""
    var searchResults: [UserModel] = []
    var isSearching = false
    var following: [UserModel] = []
    /// Reason-labeled follow suggestions for the Friends tab's discovery
    /// section. Loaded after the follow graph resolves; excludes anyone
    /// already followed, blocked, or demo.
    var suggestions: [ScoredSuggestion] = []
    /// Complete follow-state set backing isFollowing. The `following` array is
    /// only the display list (capped server-side) — deriving button state from
    /// it shows stale "Follow" buttons past the cap, which then silently no-op.
    private var followingIds: Set<String> = []
    /// Users the viewer has blocked — filtered out of search results so a
    /// blocked account can't resurface via search. Refreshed with the current
    /// user fetch in `loadFollowing()`.
    private(set) var blockedIds: Set<String> = []
    var error: Error?

    private let userRepository: any UserRepositoryProtocol
    private let userId: String
    private var searchTask: Task<Void, Never>?
    /// Current user's profile, cached for the suggestion loader (grade +
    /// home-gym override). Nil until `loadFollowing()` succeeds fetching it.
    private var viewerUser: UserModel?

    init(userRepository: any UserRepositoryProtocol, userId: String) {
        self.userRepository = userRepository
        self.userId = userId
    }

    func loadFollowing() async {
        do {
            async let listTask = userRepository.fetchFollowing(uid: userId)
            async let idsTask = userRepository.fetchFollowingIds(uid: userId)
            // Best-effort: a failed profile fetch only weakens suggestion
            // signals and skips block filtering until the next load.
            async let viewerTask = try? userRepository.fetchCurrentUser()
            let (list, ids) = try await (listTask, idsTask)
            let viewer = await viewerTask
            following = list
            followingIds = ids
            viewerUser = viewer
            blockedIds = Set(viewer?.blockedUserIds ?? [])
            await loadSuggestions()
        } catch {
            self.error = error
        }
    }

    /// Rebuilds the discovery suggestions from the current follow graph. No
    /// Discover posts are available on this tab, so gym overlap comes from
    /// home-gym overrides only (post-derived gym reasons appear on Home).
    func loadSuggestions() async {
        let viewerGyms: Set<String>
        if let gym = viewerUser?.homeGymOverride?.trimmedGymName.lowercased(), !gym.isEmpty {
            viewerGyms = [gym]
        } else {
            viewerGyms = []
        }
        suggestions = await SuggestionLoader().load(
            viewerUid: userId,
            viewerUser: viewerUser,
            followingIds: followingIds,
            discoverPosts: [],
            viewerGyms: viewerGyms,
            userRepository: userRepository,
            limit: 10
        )
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
                // Blocked users are filtered here (not in the repository) so
                // the filter always reflects the viewer's latest block list.
                searchResults = try await userRepository.searchUsers(query: query)
                    .filter { !blockedIds.contains($0.uid) }
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
            // A followed user is no longer a suggestion.
            suggestions.removeAll { $0.user.uid == user.uid }
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
