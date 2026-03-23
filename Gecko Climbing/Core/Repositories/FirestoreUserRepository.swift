import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private let db = Firestore.firestore()
    private let authRepository: any AuthRepositoryProtocol

    private var usersRef: CollectionReference { db.collection("users") }

    init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    // MARK: - Fetch

    func fetchUser(uid: String) async throws -> UserModel {
        let snapshot = try await usersRef.document(uid).getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            throw UserError.notFound
        }
        return decodeUser(from: data, uid: uid)
    }

    func fetchCurrentUser() async throws -> UserModel {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { throw UserError.notFound }

        let docRef = usersRef.document(uid)
        let snapshot = try await docRef.getDocument()

        if snapshot.exists, let data = snapshot.data() {
            return decodeUser(from: data, uid: uid)
        }

        // First sign-in — create user document from Firebase Auth profile
        let displayName = authRepository.currentUserDisplayName.isEmpty
            ? "Gecko Climber"
            : authRepository.currentUserDisplayName
        let base = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let suffix = String(uid.prefix(6))
        let username = "\(base)_\(suffix)"

        let newUser = UserModel(
            uid: uid,
            displayName: displayName,
            username: username
        )
        let dto = newUser.toDTO()
        try await docRef.setData(dto.asDictionary())
        return newUser
    }

    // MARK: - Update

    func updateUser(_ user: UserModel) async throws {
        let dto = user.toDTO()
        try await usersRef.document(user.uid).setData(dto.asDictionary(), merge: true)
    }

    // MARK: - Follow / Unfollow

    func follow(targetUID: String) async throws {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { throw UserError.notFound }

        // Guard against duplicate follows — only increment counts if not already following
        let followingRef = usersRef.document(uid).collection("following").document(targetUID)
        let existingDoc = try await followingRef.getDocument()
        guard !existingDoc.exists else { return }

        let batch = db.batch()
        let followerRef = usersRef.document(targetUID).collection("followers").document(uid)

        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: followingRef)
        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: followerRef)
        batch.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: usersRef.document(uid))
        batch.updateData(["followersCount": FieldValue.increment(Int64(1))], forDocument: usersRef.document(targetUID))

        try await batch.commit()
    }

    func unfollow(targetUID: String) async throws {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { throw UserError.notFound }

        // Only decrement if the follow relationship actually exists
        let followingRef = usersRef.document(uid).collection("following").document(targetUID)
        let followDoc = try await followingRef.getDocument()
        guard followDoc.exists else { return }

        let batch = db.batch()
        let followerRef = usersRef.document(targetUID).collection("followers").document(uid)

        batch.deleteDocument(followingRef)
        batch.deleteDocument(followerRef)
        batch.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: usersRef.document(uid))
        batch.updateData(["followersCount": FieldValue.increment(Int64(-1))], forDocument: usersRef.document(targetUID))

        try await batch.commit()
    }

    func isFollowing(targetUID: String) async throws -> Bool {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { return false }
        let doc = try await usersRef.document(uid).collection("following").document(targetUID).getDocument()
        return doc.exists
    }

    func reconcileFollowCounts(uid: String) async throws {
        let followersSnapshot = try await usersRef.document(uid).collection("followers").getDocuments()
        let followingSnapshot = try await usersRef.document(uid).collection("following").getDocuments()

        let actualFollowers = followersSnapshot.documents.count
        let actualFollowing = followingSnapshot.documents.count

        try await usersRef.document(uid).updateData([
            "followersCount": actualFollowers,
            "followingCount": actualFollowing
        ])
    }

    // MARK: - Followers / Following Lists

    func fetchFollowers(uid: String) async throws -> [UserModel] {
        let snapshot = try await usersRef.document(uid).collection("followers")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try await fetchUsers(byIds: snapshot.documents.map(\.documentID))
    }

    func fetchFollowing(uid: String) async throws -> [UserModel] {
        let snapshot = try await usersRef.document(uid).collection("following")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try await fetchUsers(byIds: snapshot.documents.map(\.documentID))
    }

    // MARK: - Search

    func searchUsers(query: String) async throws -> [UserModel] {
        guard !query.isEmpty else { return [] }

        let uid = authRepository.currentUserId
        let lowered = query.lowercased()

        // Firestore prefix search on username field
        let snapshot = try await usersRef
            .whereField("username", isGreaterThanOrEqualTo: lowered)
            .whereField("username", isLessThanOrEqualTo: lowered + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard doc.documentID != uid else { return nil }
            let data = doc.data()
            return decodeUser(from: data, uid: doc.documentID)
        }
    }

    // MARK: - Private Helpers

    private func decodeUser(from data: [String: Any], uid: String) -> UserModel {
        UserModel(
            uid: uid,
            displayName: data["displayName"] as? String ?? "",
            username: data["username"] as? String ?? "",
            bio: data["bio"] as? String ?? "",
            profileImageURL: data["profileImageURL"] as? String ?? "",
            followersCount: data["followersCount"] as? Int ?? 0,
            followingCount: data["followingCount"] as? Int ?? 0,
            totalSessions: data["totalSessions"] as? Int ?? 0,
            totalClimbs: data["totalClimbs"] as? Int ?? 0,
            highestGrade: data["highestGrade"] as? String ?? "",
            highestGradeNumeric: data["highestGradeNumeric"] as? Int ?? 0,
            isPublic: data["isPublic"] as? Bool ?? true,
            lastSyncedAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private func fetchUsers(byIds ids: [String]) async throws -> [UserModel] {
        guard !ids.isEmpty else { return [] }

        // Firestore `in` queries support up to 30 values
        var users: [UserModel] = []
        for chunk in ids.chunked(into: 30) {
            let snapshot = try await usersRef
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            users += snapshot.documents.compactMap { doc in
                let data = doc.data()
                return decodeUser(from: data, uid: doc.documentID)
            }
        }
        return users
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
