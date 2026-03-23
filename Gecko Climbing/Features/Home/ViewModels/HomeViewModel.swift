import Foundation
import Observation

@Observable @MainActor
final class HomeViewModel {
    var posts: [PostModel] = []
    var isLoading = false
    var error: Error?

    let postRepository: any PostRepositoryProtocol
    let userId: String
    var userDisplayName: String = ""
    var userProfileImageURL: String = ""

    init(postRepository: any PostRepositoryProtocol, userId: String) {
        self.postRepository = postRepository
        self.userId = userId
    }

    func updateCommentCount(postId: String, count: Int) {
        if let idx = posts.firstIndex(where: { $0.postId == postId }) {
            posts[idx].commentsCount = count
        }
    }

    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let fetched = try await postRepository.fetchFeed(for: userId)
            posts = fetched
            AnalyticsService.capture(.feedLoaded, properties: ["post_count": fetched.count])
            print("📰 Feed loaded: \(fetched.count) posts for userId: \(userId)")

            // Backfill gradeSequence for posts that don't have it
            Task {
                for post in fetched where post.gradeSequence.isEmpty && !post.sessionId.isEmpty {
                    if let sequence = try? await postRepository.backfillGradeSequence(
                        postId: post.postId, sessionId: post.sessionId
                    ) {
                        if let currentIdx = posts.firstIndex(where: { $0.postId == post.postId }) {
                            posts[currentIdx].gradeSequence = sequence
                        }
                    }
                }
            }
        } catch {
            print("❌ Feed load error: \(error)")
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
                AnalyticsService.capture(.postUnliked)
            } else {
                try await postRepository.likePost(post.postId, userId: userId)
                AnalyticsService.capture(.postLiked)
            }
        } catch {
            // Revert on failure
            posts[idx].isLikedByCurrentUser = wasLiked
            posts[idx].likesCount += wasLiked ? 1 : -1
            self.error = error
        }
    }
}
