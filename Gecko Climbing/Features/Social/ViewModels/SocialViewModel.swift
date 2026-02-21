import Foundation
import Observation

@Observable
final class SocialViewModel {
    var searchQuery = ""
    var searchResults: [UserModel] = []
    var isSearching = false
    var following: [UserModel] = []
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
            following = try await userRepository.fetchFollowing(uid: userId)
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
        do {
            try await userRepository.follow(targetUID: user.uid)
            if !following.contains(where: { $0.uid == user.uid }) {
                following.append(user)
            }
        } catch {
            self.error = error
        }
    }

    func unfollow(user: UserModel) async {
        do {
            try await userRepository.unfollow(targetUID: user.uid)
            following.removeAll { $0.uid == user.uid }
        } catch {
            self.error = error
        }
    }

    func isFollowing(_ uid: String) -> Bool {
        following.contains { $0.uid == uid }
    }
}
