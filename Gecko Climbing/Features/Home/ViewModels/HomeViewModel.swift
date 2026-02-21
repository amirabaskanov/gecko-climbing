import Foundation
import Observation

@Observable
final class HomeViewModel {
    var posts: [PostModel] = []
    var isLoading = false
    var error: Error?

    private let postRepository: any PostRepositoryProtocol
    private let userId: String

    init(postRepository: any PostRepositoryProtocol, userId: String) {
        self.postRepository = postRepository
        self.userId = userId
    }

    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            posts = try await postRepository.fetchFeed(for: userId)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func toggleLike(_ post: PostModel) async {
        guard let idx = posts.firstIndex(where: { $0.postId == post.postId }) else { return }
        let wasLiked = posts[idx].isLikedByCurrentUser
        // Optimistic update
        posts[idx].isLikedByCurrentUser = !wasLiked
        posts[idx].likesCount += wasLiked ? -1 : 1
        do {
            if wasLiked {
                try await postRepository.unlikePost(post.postId, userId: userId)
            } else {
                try await postRepository.likePost(post.postId, userId: userId)
            }
        } catch {
            // Revert on failure
            posts[idx].isLikedByCurrentUser = wasLiked
            posts[idx].likesCount += wasLiked ? 1 : -1
            self.error = error
        }
    }
}
