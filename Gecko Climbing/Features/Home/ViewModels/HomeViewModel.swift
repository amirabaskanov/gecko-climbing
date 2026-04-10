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

            // Backfill for legacy posts: legacy posts either have no gradeSequence at all
            // or have only completed climbs (missing attempts) with an empty outcomeSequence.
            // The backfill re-fetches the session and rebuilds both sequences in chronological order.
            Task { [weak self] in
                guard let self else { return }
                for post in fetched where (post.gradeSequence.isEmpty || post.outcomeSequence.isEmpty) && !post.sessionId.isEmpty {
                    do {
                        guard let result = try await self.postRepository.backfillGradeSequence(
                            postId: post.postId, sessionId: post.sessionId
                        ) else { continue }

                        guard let currentIdx = self.posts.firstIndex(where: { $0.postId == post.postId }) else { continue }
                        self.posts[currentIdx].gradeSequence = result.grades
                        self.posts[currentIdx].outcomeSequence = result.outcomes
                        // Reassign the array so SwiftUI observers tied to `posts`
                        // reliably re-render the affected card.
                        self.posts = self.posts
                        print("✅ Backfilled post \(post.postId): \(result.grades.count) climbs")
                    } catch {
                        print("⚠️ Backfill failed for post \(post.postId): \(error)")
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
