import Foundation
import FirebaseFirestore

final class FirestorePostRepository: PostRepositoryProtocol, @unchecked Sendable {
    private let db = Firestore.firestore()
    private let authRepository: any AuthRepositoryProtocol

    private var postsRef: CollectionReference { db.collection("posts") }

    init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func fetchFeed(for userId: String) async throws -> [PostModel] {
        // Fetch posts from users the current user follows, plus their own
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()

        var feedUserIds = followingSnapshot.documents.map(\.documentID)
        feedUserIds.append(userId)
        print("📰 fetchFeed: querying posts for \(feedUserIds.count) users: \(feedUserIds)")

        // Firestore `in` queries support up to 30 values
        var posts: [PostModel] = []
        for chunk in feedUserIds.chunked(into: 30) {
            let snapshot = try await postsRef
                .whereField("userId", in: chunk)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            print("📰 fetchFeed: got \(snapshot.documents.count) docs for chunk")
            posts += try await decodePosts(from: snapshot.documents, currentUserId: userId)
        }

        return posts.sorted { $0.createdAt > $1.createdAt }
    }

    func createPost(_ post: PostModel) async throws {
        var data = post.toDTO().asDictionary()
        data["createdAt"] = FieldValue.serverTimestamp()
        try await postsRef.document(post.postId).setData(data)
    }

    func likePost(_ postId: String, userId: String) async throws {
        let likeRef = postsRef.document(postId).collection("likes").document(userId)
        let existingDoc = try await likeRef.getDocument()
        guard !existingDoc.exists else { return }

        let batch = db.batch()
        let postRef = postsRef.document(postId)

        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef)

        try await batch.commit()
    }

    func unlikePost(_ postId: String, userId: String) async throws {
        let likeRef = postsRef.document(postId).collection("likes").document(userId)
        let existingDoc = try await likeRef.getDocument()
        guard existingDoc.exists else { return }

        let batch = db.batch()
        let postRef = postsRef.document(postId)

        batch.deleteDocument(likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)

        try await batch.commit()
    }

    func deletePost(_ postId: String) async throws {
        // Delete likes subcollection in chunks (Firestore batch limit is 500)
        let likesSnapshot = try await postsRef.document(postId)
            .collection("likes")
            .getDocuments()

        let likeChunks = likesSnapshot.documents.chunked(into: 499)
        for chunk in likeChunks {
            let batch = db.batch()
            for doc in chunk {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }

        // Delete the post document itself
        try await postsRef.document(postId).delete()
    }

    func reconcileLikesCount(postId: String) async throws {
        let likesSnapshot = try await postsRef.document(postId)
            .collection("likes").getDocuments()
        try await postsRef.document(postId).updateData([
            "likesCount": likesSnapshot.documents.count
        ])
    }

    func backfillGradeSequence(postId: String, sessionId: String) async throws -> (grades: [String], outcomes: [String])? {
        guard !sessionId.isEmpty else { return nil }

        // Fetch climbs from the linked session, ordered chronologically (oldest → newest)
        let climbsSnapshot = try await db.collection("sessions")
            .document(sessionId)
            .collection("climbs")
            .order(by: "loggedAt")
            .getDocuments()

        // Include all climbs — attempts render with a different texture in the feed.
        var gradeSeq: [String] = []
        var outcomeSeq: [String] = []
        for doc in climbsSnapshot.documents {
            let data = doc.data()
            guard let grade = data["grade"] as? String else { continue }
            let rawOutcome = data["outcome"] as? String ?? ""
            let outcome = ClimbOutcome.fromString(rawOutcome).rawValue
            gradeSeq.append(grade)
            outcomeSeq.append(outcome)
        }

        guard !gradeSeq.isEmpty else { return nil }

        try await postsRef.document(postId).updateData([
            "gradeSequence": gradeSeq,
            "outcomeSequence": outcomeSeq
        ])

        return (grades: gradeSeq, outcomes: outcomeSeq)
    }

    // MARK: - Comments

    func fetchComments(postId: String) async throws -> [CommentModel] {
        let snapshot = try await postsRef.document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .getDocuments()

        return snapshot.documents.map { doc in
            let data = doc.data()
            return CommentModel(
                id: doc.documentID,
                postId: postId,
                userId: data["userId"] as? String ?? "",
                userDisplayName: data["userDisplayName"] as? String ?? "",
                userProfileImageURL: data["userProfileImageURL"] as? String ?? "",
                text: data["text"] as? String ?? "",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                parentId: data["parentId"] as? String,
                replyToDisplayName: data["replyToDisplayName"] as? String,
                mentions: data["mentions"] as? [String] ?? []
            )
        }
    }

    func addComment(_ comment: CommentModel) async throws {
        let batch = db.batch()
        let commentRef = postsRef.document(comment.postId)
            .collection("comments").document(comment.id)
        let postRef = postsRef.document(comment.postId)

        var commentData: [String: Any] = [
            "userId": comment.userId,
            "userDisplayName": comment.userDisplayName,
            "userProfileImageURL": comment.userProfileImageURL,
            "text": comment.text,
            "mentions": comment.mentions,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let parentId = comment.parentId {
            commentData["parentId"] = parentId
        }
        if let replyTo = comment.replyToDisplayName {
            commentData["replyToDisplayName"] = replyTo
        }
        batch.setData(commentData, forDocument: commentRef)

        batch.updateData([
            "commentsCount": FieldValue.increment(Int64(1))
        ], forDocument: postRef)

        try await batch.commit()
    }

    func deleteComment(postId: String, commentId: String) async throws {
        let commentRef = postsRef.document(postId)
            .collection("comments").document(commentId)
        let existingDoc = try await commentRef.getDocument()
        guard existingDoc.exists else { return }

        let batch = db.batch()
        batch.deleteDocument(commentRef)
        batch.updateData([
            "commentsCount": FieldValue.increment(Int64(-1))
        ], forDocument: postsRef.document(postId))

        try await batch.commit()
    }

    func deletePostBySessionId(_ sessionId: String) async throws {
        let snapshot = try await postsRef
            .whereField("sessionId", isEqualTo: sessionId)
            .getDocuments()

        for doc in snapshot.documents {
            try await deletePost(doc.documentID)
        }
    }

    func fetchPosts(for userId: String) async throws -> [PostModel] {
        let snapshot = try await postsRef
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        let currentUserId = authRepository.currentUserId
        return try await decodePosts(from: snapshot.documents, currentUserId: currentUserId)
    }

    // MARK: - Private

    private func decodePosts(from documents: [QueryDocumentSnapshot], currentUserId: String) async throws -> [PostModel] {
        let posts = documents.map { doc in
            decodePost(from: doc.data(), id: doc.documentID)
        }

        // Batch-check likes: fetch all like docs concurrently instead of N+1 sequential reads
        if !currentUserId.isEmpty && !posts.isEmpty {
            await withTaskGroup(of: (String, Bool).self) { group in
                for post in posts {
                    group.addTask {
                        let likeDoc = try? await self.postsRef
                            .document(post.postId)
                            .collection("likes")
                            .document(currentUserId)
                            .getDocument()
                        return (post.postId, likeDoc?.exists ?? false)
                    }
                }
                for await (postId, isLiked) in group {
                    if let post = posts.first(where: { $0.postId == postId }) {
                        post.isLikedByCurrentUser = isLiked
                    }
                }
            }
        }

        return posts
    }

    private func decodePost(from data: [String: Any], id: String) -> PostModel {
        PostModel(
            postId: id,
            userId: data["userId"] as? String ?? "",
            userDisplayName: data["userDisplayName"] as? String ?? "",
            userProfileImageURL: data["userProfileImageURL"] as? String ?? "",
            sessionId: data["sessionId"] as? String ?? "",
            gymName: data["gymName"] as? String ?? "",
            type: data["type"] as? String ?? "session",
            caption: data["caption"] as? String ?? "",
            imageURL: data["imageURL"] as? String,
            imageURLs: data["imageURLs"] as? [String] ?? [],
            likesCount: data["likesCount"] as? Int ?? 0,
            commentsCount: data["commentsCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            topGrade: data["topGrade"] as? String ?? "",
            topGradeNumeric: data["topGradeNumeric"] as? Int ?? 0,
            totalClimbs: data["totalClimbs"] as? Int ?? 0,
            gradeCounts: data["gradeCounts"] as? [String: Int] ?? [:],
            gradeSequence: data["gradeSequence"] as? [String] ?? [],
            outcomeSequence: data["outcomeSequence"] as? [String] ?? [],
            visibility: data["visibility"] as? String ?? "followers"
        )
    }
}

// MARK: - Array Chunking Helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
