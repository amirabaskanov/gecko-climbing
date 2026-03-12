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

        // Firestore `in` queries support up to 30 values
        var posts: [PostModel] = []
        for chunk in feedUserIds.chunked(into: 30) {
            let snapshot = try await postsRef
                .whereField("userId", in: chunk)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

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
        let batch = db.batch()
        let likeRef = postsRef.document(postId).collection("likes").document(userId)
        let postRef = postsRef.document(postId)

        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef)

        try await batch.commit()
    }

    func unlikePost(_ postId: String, userId: String) async throws {
        let batch = db.batch()
        let likeRef = postsRef.document(postId).collection("likes").document(userId)
        let postRef = postsRef.document(postId)

        batch.deleteDocument(likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)

        try await batch.commit()
    }

    func deletePost(_ postId: String) async throws {
        // Delete likes subcollection
        let likesSnapshot = try await postsRef.document(postId)
            .collection("likes")
            .getDocuments()

        let batch = db.batch()
        for doc in likesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(postsRef.document(postId))
        try await batch.commit()
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
        var posts: [PostModel] = []

        for doc in documents {
            let data = doc.data()
            let post = decodePost(from: data, id: doc.documentID)

            // Check if current user has liked this post
            if !currentUserId.isEmpty {
                let likeDoc = try await postsRef
                    .document(doc.documentID)
                    .collection("likes")
                    .document(currentUserId)
                    .getDocument()
                post.isLikedByCurrentUser = likeDoc.exists
            }

            posts.append(post)
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
            likesCount: data["likesCount"] as? Int ?? 0,
            commentsCount: data["commentsCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            topGrade: data["topGrade"] as? String ?? "",
            topGradeNumeric: data["topGradeNumeric"] as? Int ?? 0,
            totalClimbs: data["totalClimbs"] as? Int ?? 0,
            gradeCounts: data["gradeCounts"] as? [String: Int] ?? [:],
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
