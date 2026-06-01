import Foundation

// MARK: - Protocol
protocol PostRepositoryProtocol: AnyObject {
    func fetchFeed(for userId: String) async throws -> [PostModel]
    /// Public, recent posts for the Discover rail. Implementations exclude
    /// `FeedConfig.demoUserIds` and any posts older than the discover window.
    /// Ordering and final ranking happen client-side via `FeedRanker`.
    func fetchDiscover(for userId: String) async throws -> [PostModel]
    func createPost(_ post: PostModel) async throws
    func likePost(_ postId: String, userId: String) async throws
    func unlikePost(_ postId: String, userId: String) async throws
    func deletePost(_ postId: String) async throws
    func deletePostBySessionId(_ sessionId: String) async throws
    func fetchPosts(for userId: String) async throws -> [PostModel]
    /// Fetch a single post by id, regardless of feed membership. Used for
    /// deep links (e.g. a like or comment notification) where the target
    /// post may not be in the viewer's loaded feed. Returns nil if the post
    /// no longer exists.
    func fetchPost(postId: String) async throws -> PostModel?
    func reconcileLikesCount(postId: String) async throws
    func backfillGradeSequence(postId: String, sessionId: String) async throws -> (grades: [String], outcomes: [String])?
    func fetchComments(postId: String) async throws -> [CommentModel]
    func addComment(_ comment: CommentModel) async throws
    func deleteComment(postId: String, commentId: String) async throws

    /// Cascade an author's denormalized profile fields (`userDisplayName`,
    /// `userProfileImageURL`) to every post they've authored. Called after
    /// the user edits their profile so old posts don't keep showing stale
    /// names or avatars. Best-effort — the user's profile change is the
    /// source of truth and shouldn't fail if the cascade does.
    func cascadeAuthorMetadata(
        uid: String,
        displayName: String,
        profileImageURL: String
    ) async throws
}

// MARK: - Mock Implementation
final class MockPostRepository: PostRepositoryProtocol, @unchecked Sendable {
    private var posts: [PostModel]
    private var likedPostIds: Set<String> = []
    private var mockComments: [String: [CommentModel]] = [:]

    init() {
        let seeded = Self.makeSeedPosts()
        self.posts = seeded.posts
        self.mockComments = seeded.comments
        // A handful of posts the current user already liked — gives the feed
        // a mix of liked/unliked hearts on first render.
        self.likedPostIds = seeded.likedPostIds
    }

    func fetchFeed(for userId: String) async throws -> [PostModel] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return posts
            .filter { !FeedConfig.demoUserIds.contains($0.userId) }
            .sorted { $0.createdAt > $1.createdAt }
            .map { post in
                let p = post
                p.isLikedByCurrentUser = likedPostIds.contains(p.postId)
                return p
            }
    }

    func fetchDiscover(for userId: String) async throws -> [PostModel] {
        try await Task.sleep(nanoseconds: 400_000_000)
        let cutoff = Date().addingTimeInterval(-Double(FeedConfig.discoverWindowDays) * 86_400)
        return posts
            .filter { !FeedConfig.demoUserIds.contains($0.userId) }
            .filter { $0.createdAt >= cutoff }
            .filter { $0.userId != userId }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(FeedConfig.discoverFetchLimit)
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

    func deletePostBySessionId(_ sessionId: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        posts.removeAll { $0.sessionId == sessionId }
    }

    func fetchPosts(for userId: String) async throws -> [PostModel] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return posts.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchPost(postId: String) async throws -> PostModel? {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let post = posts.first(where: { $0.postId == postId }) else { return nil }
        post.isLikedByCurrentUser = likedPostIds.contains(post.postId)
        return post
    }

    func reconcileLikesCount(postId: String) async throws {
        // No-op for mock
    }

    func backfillGradeSequence(postId: String, sessionId: String) async throws -> (grades: [String], outcomes: [String])? {
        return nil // No-op for mock
    }

    func fetchComments(postId: String) async throws -> [CommentModel] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return mockComments[postId] ?? []
    }

    func addComment(_ comment: CommentModel) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        mockComments[comment.postId, default: []].append(comment)
        if let idx = posts.firstIndex(where: { $0.postId == comment.postId }) {
            posts[idx].commentsCount += 1
        }
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        mockComments[postId]?.removeAll { $0.id == commentId }
        if let idx = posts.firstIndex(where: { $0.postId == postId }) {
            posts[idx].commentsCount = max(0, posts[idx].commentsCount - 1)
        }
    }

    func cascadeAuthorMetadata(
        uid: String,
        displayName: String,
        profileImageURL: String
    ) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        for idx in posts.indices where posts[idx].userId == uid {
            posts[idx].userDisplayName = displayName
            posts[idx].userProfileImageURL = profileImageURL
        }
    }

    private struct SeedDraft {
        let userId: String
        let gym: String
        let caption: String
        let imageURLs: [String]
        let hoursAgo: Double
        let likes: Int
        /// (grade, outcome) pairs in chronological order — a real session
        /// arc: easy warm-up climbs, then peak attempts, then easier cool-down.
        let arc: [(String, ClimbOutcome)]
        /// Comment author UIDs and bodies, in order. Empty = no comment thread.
        let comments: [(String, String)]
        /// True when the current viewer (Kai) has already liked this post.
        let likedByMe: Bool
    }

    private static func makeSeedPosts() -> (posts: [PostModel], comments: [String: [CommentModel]], likedPostIds: Set<String>) {

        // The cast. Captions are written so each climber's voice carries
        // through. Photos pulled from the bundle via `bundle:` refs and
        // resolved by `Image.bundled(from:)`.
        let drafts: [SeedDraft] = [

            // 1. Kai · 4h ago · V7 send at Dogpatch (App Store flagship)
            SeedDraft(
                userId: MockSeed.kaiUserId,
                gym: "Dogpatch Boulders",
                caption: "Sent V7 today!! Heel toe finally locked in after 5 attempts. Already eyeing the V8 in the corner 👀",
                imageURLs: [MockSeed.climbIndoorMale1],
                hoursAgo: 4,
                likes: 47,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .flash),
                    ("V4", .sent), ("V5", .flash), ("V5", .sent),
                    ("V6", .sent), ("V7", .sent), ("V7", .attempt),
                    ("V8", .attempt), ("V4", .sent), ("V3", .flash)
                ],
                comments: [
                    (MockSeed.rileyUserId, "let's goooo!! that wall has been brutal"),
                    (MockSeed.jordanUserId, "V7 IN THE BAG 🔥🔥🔥"),
                    (MockSeed.naomiUserId, "huge. send me the V8 beta when you get it"),
                    (MockSeed.mayaUserId, "okay but how is the heel toe, i need beta")
                ],
                likedByMe: false
            ),

            // 2. Riley · 8h ago · Hollywood project send
            SeedDraft(
                userId: MockSeed.rileyUserId,
                gym: "Hollywood Boulders",
                caption: "Hollywood was setting hard today. Pink V5 in the cave finally went after working it for a month. Pumped 💪",
                imageURLs: [MockSeed.climbIndoorFemale1],
                hoursAgo: 8,
                likes: 64,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V3", .sent),
                    ("V4", .flash), ("V4", .sent), ("V5", .attempt),
                    ("V5", .sent), ("V5", .sent), ("V6", .attempt),
                    ("V4", .flash), ("V3", .flash)
                ],
                comments: [
                    (MockSeed.kaiUserId, "huge. pink V5 has been the gatekeeper for everyone"),
                    (MockSeed.mayaUserId, "queen 👑"),
                    (MockSeed.jordanUserId, "PINK SLAYER"),
                    (MockSeed.marcoUserId, "took you a month? i've been on it 6"),
                    (MockSeed.rileyUserId, "@marco keep going!! you got this"),
                    (MockSeed.kaiUserId, "@marco you'll get the next session i can feel it")
                ],
                likedByMe: true
            ),

            // 3. Jordan · 14h ago · The Spot V4 milestone (no photo)
            SeedDraft(
                userId: MockSeed.jordanUserId,
                gym: "The Spot Boulder",
                caption: "BACK TO BACK V4 FLASHES TODAY YES YES YES finally feel like im climbing v4 not just sending v4",
                imageURLs: [],
                hoursAgo: 14,
                likes: 38,
                arc: [
                    ("V1", .flash), ("V2", .flash), ("V3", .flash),
                    ("V4", .flash), ("V4", .flash), ("V4", .sent),
                    ("V3", .flash), ("V3", .sent)
                ],
                comments: [
                    (MockSeed.kaiUserId, "huge. that's the unlock"),
                    (MockSeed.rileyUserId, "ICONIC 🔥"),
                    (MockSeed.mayaUserId, "this is so motivating to read")
                ],
                likedByMe: true
            ),

            // 4. Maya · 1d ago · FIRST V3 (high engagement milestone)
            SeedDraft(
                userId: MockSeed.mayaUserId,
                gym: "Dogpatch Boulders",
                caption: "5 months in and FIRST V3 today. I might have cried a little. Marco said embarrassing but i think it's earned 🥹",
                imageURLs: [],
                hoursAgo: 26,
                likes: 89,
                arc: [
                    ("V0", .flash), ("V1", .flash), ("V1", .flash),
                    ("V2", .flash), ("V2", .sent), ("V2", .sent),
                    ("V3", .attempt), ("V3", .attempt), ("V3", .sent),
                    ("V2", .flash)
                ],
                comments: [
                    (MockSeed.rileyUserId, "MAYAAA so proud of you 🎉"),
                    (MockSeed.kaiUserId, "huge milestone. first of many"),
                    (MockSeed.jordanUserId, "FIRST V3 IS SUCH A FEELING"),
                    (MockSeed.marcoUserId, "i was already proud. now more proud"),
                    (MockSeed.mayaUserId, "@marco stop you're going to make me cry again"),
                    (MockSeed.rileyUserId, "second this. you got this")
                ],
                likedByMe: true
            ),

            // 5. Marco · 1d ago · Dogpatch with Maya (no photo)
            SeedDraft(
                userId: MockSeed.marcoUserId,
                gym: "Dogpatch Boulders",
                caption: "Tuesday at Dogpatch. Some V4s, some V5s. mostly tired. Maya sent her first V3 today which made my whole month",
                imageURLs: [],
                hoursAgo: 27,
                likes: 31,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V3", .sent),
                    ("V4", .sent), ("V4", .sent), ("V5", .attempt),
                    ("V5", .sent), ("V4", .sent), ("V3", .flash)
                ],
                comments: [
                    (MockSeed.mayaUserId, "🥹🥹🥹"),
                    (MockSeed.rileyUserId, "best gym partner award goes to"),
                    (MockSeed.kaiUserId, "Marco the encourager era")
                ],
                likedByMe: false
            ),

            // 6. Kai · 2d ago · Dogpatch V6
            SeedDraft(
                userId: MockSeed.kaiUserId,
                gym: "Dogpatch Boulders",
                caption: "Compression V6 in the back room. Spent half the session on it. Got the send but my forearms are pudding.",
                imageURLs: [MockSeed.climbIndoorMale2],
                hoursAgo: 50,
                likes: 32,
                arc: [
                    ("V1", .flash), ("V3", .flash), ("V4", .flash),
                    ("V5", .flash), ("V5", .sent), ("V6", .attempt),
                    ("V6", .attempt), ("V6", .sent), ("V4", .flash)
                ],
                comments: [
                    (MockSeed.marcoUserId, "compression V6 is a personal attack"),
                    (MockSeed.rileyUserId, "the back room sets so hard")
                ],
                likedByMe: false
            ),

            // 7. Riley · 3d ago · outdoor day
            SeedDraft(
                userId: MockSeed.rileyUserId,
                gym: "Bishop, CA",
                caption: "First outdoor day of the year. The rock is humbling. V3 outdoors felt harder than V5 indoors. Beautiful day though.",
                imageURLs: [MockSeed.climbOutdoorFemale],
                hoursAgo: 76,
                likes: 71,
                arc: [
                    ("V1", .flash), ("V2", .flash), ("V2", .sent),
                    ("V3", .attempt), ("V3", .attempt), ("V3", .sent),
                    ("V4", .attempt), ("V2", .flash)
                ],
                comments: [
                    (MockSeed.mayaUserId, "this is gorgeous, where is this?"),
                    (MockSeed.rileyUserId, "@maya outside Bishop! incredible spot"),
                    (MockSeed.kaiUserId, "psyched for you"),
                    (MockSeed.jordanUserId, "outdoor sandbag is REAL")
                ],
                likedByMe: true
            ),

            // 8. Naomi · 4d ago · CRG Harvard V7 (NEW)
            SeedDraft(
                userId: MockSeed.naomiUserId,
                gym: "CRG Harvard Square",
                caption: "Sent the comp wall V7 finally. Three sessions of figuring out the toe hook and it just clicked today.",
                imageURLs: [MockSeed.gymCRGHarvard],
                hoursAgo: 95,
                likes: 58,
                arc: [
                    ("V3", .flash), ("V4", .flash), ("V4", .sent),
                    ("V5", .flash), ("V5", .sent), ("V6", .sent),
                    ("V6", .sent), ("V7", .sent), ("V7", .attempt),
                    ("V5", .flash)
                ],
                comments: [
                    (MockSeed.kaiUserId, "huge!! the toe hook on that one is wild"),
                    (MockSeed.rileyUserId, "absolute crusher"),
                    (MockSeed.naomiUserId, "@kai when are you back in Boston, V8 awaits")
                ],
                likedByMe: false
            ),

            // 9. Jordan · 4d ago · attempts day
            SeedDraft(
                userId: MockSeed.jordanUserId,
                gym: "The Spot Boulder",
                caption: "Spent an hour and a half on one V5 today. Did not send. Will return. The crimps know what they did.",
                imageURLs: [],
                hoursAgo: 100,
                likes: 24,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V3", .sent),
                    ("V4", .flash), ("V5", .attempt), ("V5", .attempt),
                    ("V5", .attempt), ("V4", .flash), ("V3", .flash)
                ],
                comments: [
                    (MockSeed.kaiUserId, "sometimes the rock wins. tomorrow you win"),
                    (MockSeed.marcoUserId, "what crimps were involved"),
                    (MockSeed.jordanUserId, "@marco evil ones")
                ],
                likedByMe: false
            ),

            // 10. Kai · 5d ago · Hollywood visit (gym-hollywood photo)
            SeedDraft(
                userId: MockSeed.kaiUserId,
                gym: "Hollywood Boulders",
                caption: "In LA for the weekend. Riley took me to Hollywood. Their V6 setting is genuinely wild.",
                imageURLs: [MockSeed.gymHollywood],
                hoursAgo: 122,
                likes: 41,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .sent),
                    ("V5", .flash), ("V5", .sent), ("V6", .sent),
                    ("V6", .attempt), ("V7", .attempt), ("V5", .sent),
                    ("V3", .flash)
                ],
                comments: [
                    (MockSeed.rileyUserId, "come back any time, we'll project the V7"),
                    (MockSeed.mayaUserId, "double crew session goals")
                ],
                likedByMe: false
            ),

            // 11. Marco · 6d ago · slab session
            SeedDraft(
                userId: MockSeed.marcoUserId,
                gym: "Pacific Pipe",
                caption: "Tried a slab today. Remembered why I do overhangs. Anyway V4 for the day, smashing for me.",
                imageURLs: [],
                hoursAgo: 148,
                likes: 19,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V3", .sent),
                    ("V4", .attempt), ("V4", .sent), ("V3", .flash)
                ],
                comments: [
                    (MockSeed.rileyUserId, "slab supremacy, wake up"),
                    (MockSeed.marcoUserId, "@riley i refuse")
                ],
                likedByMe: false
            ),

            // 12. Maya · 7d ago · V3 project (pre-send)
            SeedDraft(
                userId: MockSeed.mayaUserId,
                gym: "Dogpatch Boulders",
                caption: "Still working that V3 in the back corner. Closer every session. Falling on the same move every single time but I will get it 😤",
                imageURLs: [],
                hoursAgo: 170,
                likes: 22,
                arc: [
                    ("V0", .flash), ("V1", .flash), ("V2", .flash),
                    ("V2", .sent), ("V3", .attempt), ("V3", .attempt),
                    ("V3", .attempt), ("V2", .sent)
                ],
                comments: [
                    (MockSeed.kaiUserId, "you'll get it. that move is yours"),
                    (MockSeed.jordanUserId, "the falls are part of the send 🙌")
                ],
                likedByMe: true
            ),

            // 13. Kai · 8d ago · quick Dogpatch session, no photo
            SeedDraft(
                userId: MockSeed.kaiUserId,
                gym: "Dogpatch Boulders",
                caption: "Lunch sesh. V4s and V5s, nothing special. Sometimes you just gotta move.",
                imageURLs: [],
                hoursAgo: 196,
                likes: 14,
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .flash),
                    ("V4", .sent), ("V5", .sent)
                ],
                comments: [],
                likedByMe: false
            ),

            // 14. Marco · 14d ago · outdoor rest day photo
            SeedDraft(
                userId: MockSeed.marcoUserId,
                gym: "Castle Rock State Park",
                caption: "Rest day from the gym, went hiking. Found this rock. Did not climb it. Or did I.",
                imageURLs: [MockSeed.climbOutdoorMale],
                hoursAgo: 340,
                likes: 28,
                arc: [],
                comments: [
                    (MockSeed.rileyUserId, "you climbed it"),
                    (MockSeed.kaiUserId, "rest day is when the gains compound")
                ],
                likedByMe: false
            )
        ]

        var posts: [PostModel] = []
        var commentsMap: [String: [CommentModel]] = [:]
        var likedIds: Set<String> = []

        for draft in drafts {
            // Build grade counts + sequences from the chronological arc.
            let completedArc = draft.arc.filter { $0.1.isCompleted }
            var gradeCounts: [String: Int] = [:]
            for (grade, _) in completedArc {
                gradeCounts[grade, default: 0] += 1
            }
            let gradeSeq = draft.arc.map { $0.0 }
            let outcomeSeq = draft.arc.map { $0.1.rawValue }

            let topCompleted = completedArc.max(by: { VGrade.numeric(for: $0.0) < VGrade.numeric(for: $1.0) })
            let topGrade = topCompleted?.0 ?? ""
            let topNum = topCompleted.map { VGrade.numeric(for: $0.0) } ?? -1

            let post = PostModel(
                userId: draft.userId,
                userDisplayName: MockSeed.displayName(for: draft.userId),
                userProfileImageURL: MockSeed.avatarURL(for: draft.userId),
                sessionId: UUID().uuidString,
                gymName: draft.gym,
                caption: draft.caption,
                imageURL: draft.imageURLs.first,
                imageURLs: draft.imageURLs,
                likesCount: draft.likes,
                commentsCount: draft.comments.count,
                createdAt: Date().addingTimeInterval(-draft.hoursAgo * 3600),
                isLikedByCurrentUser: draft.likedByMe,
                topGrade: topGrade,
                topGradeNumeric: topNum,
                totalClimbs: completedArc.count,
                gradeCounts: gradeCounts,
                gradeSequence: gradeSeq,
                outcomeSequence: outcomeSeq
            )
            posts.append(post)

            if draft.likedByMe {
                likedIds.insert(post.postId)
            }

            if !draft.comments.isEmpty {
                commentsMap[post.postId] = draft.comments.enumerated().map { idx, c in
                    CommentModel(
                        postId: post.postId,
                        userId: c.0,
                        userDisplayName: MockSeed.displayName(for: c.0),
                        userProfileImageURL: MockSeed.avatarURL(for: c.0),
                        text: c.1,
                        createdAt: post.createdAt.addingTimeInterval(Double(idx + 1) * 1800)
                    )
                }
            }
        }

        return (posts, commentsMap, likedIds)
    }
}
