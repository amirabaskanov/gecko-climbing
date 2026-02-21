import Foundation

// MARK: - Protocol
protocol PostRepositoryProtocol: AnyObject {
    func fetchFeed(for userId: String) async throws -> [PostModel]
    func createPost(_ post: PostModel) async throws
    func likePost(_ postId: String, userId: String) async throws
    func unlikePost(_ postId: String, userId: String) async throws
    func deletePost(_ postId: String) async throws
    func fetchPosts(for userId: String) async throws -> [PostModel]
}

// MARK: - Mock Implementation
final class MockPostRepository: PostRepositoryProtocol, @unchecked Sendable {
    private var posts: [PostModel]
    private var likedPostIds: Set<String> = []

    init() {
        self.posts = Self.makeSeedPosts()
    }

    func fetchFeed(for userId: String) async throws -> [PostModel] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return posts
            .sorted { $0.createdAt > $1.createdAt }
            .map { post in
                let p = post
                p.isLikedByCurrentUser = likedPostIds.contains(p.postId)
                return p
            }
    }

    func createPost(_ post: PostModel) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        posts.insert(post, at: 0)
    }

    func likePost(_ postId: String, userId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        likedPostIds.insert(postId)
        if let idx = posts.firstIndex(where: { $0.postId == postId }) {
            posts[idx].likesCount += 1
            posts[idx].isLikedByCurrentUser = true
        }
    }

    func unlikePost(_ postId: String, userId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        likedPostIds.remove(postId)
        if let idx = posts.firstIndex(where: { $0.postId == postId }) {
            posts[idx].likesCount = max(0, posts[idx].likesCount - 1)
            posts[idx].isLikedByCurrentUser = false
        }
    }

    func deletePost(_ postId: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        posts.removeAll { $0.postId == postId }
    }

    func fetchPosts(for userId: String) async throws -> [PostModel] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return posts.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }

    private static func makeSeedPosts() -> [PostModel] {
        let data: [(String, String, String, String, Int, String, Int, [String: Int])] = [
            ("friend_1", "Sam Rocks", "The Climbing Hangar", "Finally sent the red V8! Took 3 sessions but worth it 🎉", 12, "V8", 8, ["V5": 2, "V6": 3, "V7": 2, "V8": 1]),
            ("friend_2", "Jordan Peak", "Boulder World", "Good sesh today. Warmed up on V3s then pushed to V5.", 5, "V5", 5, ["V3": 4, "V4": 3, "V5": 2]),
            ("friend_3", "Casey Wall", "Bloc Shop", "Comp training — focused on volume today. 20 climbs!", 24, "V10", 10, ["V7": 5, "V8": 8, "V9": 5, "V10": 2]),
            ("friend_4", "Morgan Crimp", "The Arch", "First time at The Arch. Amazing setting!", 7, "V6", 6, ["V4": 3, "V5": 4, "V6": 2]),
            ("friend_1", "Sam Rocks", "Boulder World", "Quick lunch session. Still sore from yesterday.", 3, "V7", 7, ["V5": 3, "V6": 2, "V7": 1])
        ]

        return data.enumerated().map { idx, d in
            let (userId, name, gym, caption, likes, topGrade, topNum, gradeCounts) = d
            return PostModel(
                userId: userId,
                userDisplayName: name,
                sessionId: UUID().uuidString,
                gymName: gym,
                caption: caption,
                likesCount: likes,
                commentsCount: Int.random(in: 0...5),
                createdAt: Date().addingTimeInterval(-Double(idx) * 3600 * 6),
                topGrade: topGrade,
                topGradeNumeric: topNum,
                totalClimbs: gradeCounts.values.reduce(0, +),
                gradeCounts: gradeCounts
            )
        }
    }
}
