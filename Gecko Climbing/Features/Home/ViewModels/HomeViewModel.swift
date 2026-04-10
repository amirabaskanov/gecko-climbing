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

    private var backfillTask: Task<Void, Never>?

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
        // Cancel any prior backfill so it can't race against the new feed snapshot.
        backfillTask?.cancel()
        do {
            let fetched = try await postRepository.fetchFeed(for: userId)
            posts = fetched
            AnalyticsService.capture(.feedLoaded, properties: ["post_count": fetched.count])
            print("📰 Feed loaded: \(fetched.count) posts for userId: \(userId)")

            // Backfill for legacy posts: legacy posts either have no gradeSequence at all
            // or have only completed climbs (missing attempts) with an empty outcomeSequence.
            // The backfill re-fetches the session and rebuilds both sequences in chronological order.
            backfillTask = Task { [weak self] in
                guard let self else { return }
                let candidates = fetched.filter {
                    ($0.gradeSequence.isEmpty || $0.outcomeSequence.isEmpty) && !$0.sessionId.isEmpty
                }
                guard !candidates.isEmpty else { return }

                // Build mutations in a local dictionary, then apply them in a single
                // assignment after the loop so SwiftUI observers don't re-render per item.
                var updates: [String: (grades: [String], outcomes: [String])] = [:]
                for post in candidates {
                    if Task.isCancelled { return }
                    do {
                        guard let result = try await self.postRepository.backfillGradeSequence(
                            postId: post.postId, sessionId: post.sessionId
                        ) else { continue }
                        if Task.isCancelled { return }
                        updates[post.postId] = (result.grades, result.outcomes)
                        print("✅ Backfilled post \(post.postId): \(result.grades.count) climbs")
                    } catch {
                        print("⚠️ Backfill failed for post \(post.postId): \(error)")
                    }
                }

                if Task.isCancelled || updates.isEmpty { return }
                // Single publish: rebuild the array once with all backfilled fields applied.
                let newPosts = self.posts
                for idx in newPosts.indices {
                    if let update = updates[newPosts[idx].postId] {
                        newPosts[idx].gradeSequence = update.grades
                        newPosts[idx].outcomeSequence = update.outcomes
                    }
                }
                self.posts = newPosts
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
