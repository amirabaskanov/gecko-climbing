import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirestoreUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private let db = Firestore.firestore()
    private let authRepository: any AuthRepositoryProtocol

    private var usersRef: CollectionReference { db.collection("users") }
    private var usernamesRef: CollectionReference { db.collection("usernames") }

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
            let user = decodeUser(from: data, uid: uid)
            // Best-effort migration for users created before username reservations
            // existed: ensure their handle matches the regex and that a
            // reservation document exists. If we have to repair the handle,
            // return the repaired one to the caller so the UI doesn't briefly
            // show an old/invalid username.
            if let repaired = try? await migrateLegacyUserIfNeeded(user) {
                return repaired
            }
            return user
        }

        // First sign-in — create user document from Firebase Auth profile.
        // Apple returns fullName only on the very first authorization per (Apple ID, bundle ID);
        // if the Firebase Auth displayName ended up empty, fall back to the Firebase email
        // local-part before resorting to a generic placeholder.
        let authDisplayName = authRepository.currentUserDisplayName
        let emailLocal: String? = {
            guard let email = Auth.auth().currentUser?.email,
                  !email.contains("@privaterelay.appleid.com"),
                  let local = email.split(separator: "@").first else { return nil }
            return String(local)
        }()
        let displayName: String = {
            if !authDisplayName.isEmpty { return authDisplayName }
            if let emailLocal, !emailLocal.isEmpty { return emailLocal }
            return "Climber"
        }()
        let suffix = String(uid.prefix(6))
        let username = "\(usernameBase(from: displayName))_\(suffix.lowercased())"

        let newUser = UserModel(
            uid: uid,
            displayName: displayName,
            username: username
        )
        // The transaction-based createUser writes to /usernames/, which is
        // gated by rules that may not be deployed yet. If we hit
        // permission-denied, fall back to a plain user-doc write so sign-up
        // still completes — the next sign-in will retry the reservation via
        // migrateLegacyUserIfNeeded once rules are live.
        do {
            try await createUser(newUser, documentRef: docRef)
        } catch where isPermissionDenied(error) {
            try await docRef.setData(newUser.toDTO().asDictionary())
        }
        return newUser
    }

    // MARK: - Update

    func updateUser(_ user: UserModel) async throws {
        try validateUsername(user.username)
        // Same rules-not-yet-deployed fallback as createUser. Without the
        // /usernames/ rules in place, the reservation transaction returns
        // permission-denied; we still want the user's edits to land.
        do {
            try await runUserUpdateTransaction(user)
        } catch where isPermissionDenied(error) {
            try await updateUserWithoutReservation(user)
        }
    }

    private func updateUserWithoutReservation(_ user: UserModel) async throws {
        // Best-effort uniqueness without the reservation infra: query the
        // users collection for the same username and reject if it belongs to
        // someone else. Race-condition prone (two writers can both pass this
        // check before either commits), but acceptable as a launch-day
        // fallback until /usernames/ rules ship.
        let snapshot = try await usersRef
            .whereField("username", isEqualTo: user.username)
            .limit(to: 2)
            .getDocuments()
        if snapshot.documents.contains(where: { $0.documentID != user.uid }) {
            throw UserError.usernameTaken
        }
        try await usersRef.document(user.uid).setData(user.toDTO().asDictionary(), merge: true)
    }

    private func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain &&
            nsError.code == FirestoreErrorCode.permissionDenied.rawValue
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

    // MARK: - Notification Preferences

    func fetchNotificationPrefs(for userId: String) async throws -> NotificationPrefs {
        let snapshot = try await usersRef.document(userId).getDocument()
        let data = snapshot.data()
        return NotificationPrefs(dictionary: data?["notificationPrefs"] as? [String: Any])
    }

    func updateNotificationPrefs(_ prefs: NotificationPrefs, for userId: String) async throws {
        try await usersRef.document(userId).setData(
            ["notificationPrefs": prefs.asDictionary],
            merge: true
        )
    }

    func registerFCMToken(_ token: String, for userId: String) async throws {
        try await usersRef.document(userId).setData(
            ["fcmTokens": FieldValue.arrayUnion([token])],
            merge: true
        )
    }

    func updateTimeZone(_ identifier: String, for userId: String) async throws {
        try await usersRef.document(userId).setData(
            ["timeZone": identifier],
            merge: true
        )
    }

    // MARK: - Blocking

    func blockUser(_ targetUserId: String) async throws {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { throw UserError.notFound }
        try await usersRef.document(uid).updateData([
            "blockedUserIds": FieldValue.arrayUnion([targetUserId])
        ])
    }

    func unblockUser(_ targetUserId: String) async throws {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { throw UserError.notFound }
        try await usersRef.document(uid).updateData([
            "blockedUserIds": FieldValue.arrayRemove([targetUserId])
        ])
    }

    func fetchBlockedUsers() async throws -> [UserModel] {
        let me = try await fetchCurrentUser()
        let ids = me.blockedUserIds
        guard !ids.isEmpty else { return [] }
        let users = try await fetchUsers(byIds: ids)
        // Preserve the order users blocked people in (Firestore `whereField in`
        // does not guarantee order). `fetchUsers(byIds:)` already returns
        // models in id order, so we re-sort to match the source array.
        let lookup = Dictionary(uniqueKeysWithValues: users.map { ($0.uid, $0) })
        return ids.compactMap { lookup[$0] }
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

    // MARK: - Suggested climbers

    func suggestedClimbers(excluding excludedUIDs: Set<String>, limit: Int) async throws -> [UserModel] {
        // Active climbers ranked by sessions logged. Cheap to query (single
        // index, no joins) and a strong heuristic for "real users worth
        // following" without needing engagement data we don't yet collect.
        // Demo accounts and the caller's own uid + follow set are filtered
        // client-side so we don't burn an extra index per excluded uid.
        let snapshot = try await usersRef
            .order(by: "totalSessions", descending: true)
            .limit(to: limit + excludedUIDs.count + FeedConfig.demoUserIds.count + 1)
            .getDocuments()

        let allExcluded = excludedUIDs.union(FeedConfig.demoUserIds)
        return snapshot.documents.compactMap { doc -> UserModel? in
            guard !allExcluded.contains(doc.documentID) else { return nil }
            return decodeUser(from: doc.data(), uid: doc.documentID)
        }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Private Helpers

    private func createUser(_ user: UserModel, documentRef: DocumentReference) async throws {
        try validateUsername(user.username)
        let usernameRef = usernamesRef.document(user.username)
        let dto = user.toDTO()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction { transaction, errorPointer in
                do {
                    let usernameSnapshot = try transaction.getDocument(usernameRef)
                    if usernameSnapshot.exists {
                        throw UserError.usernameTaken
                    }

                    transaction.setData(dto.asDictionary(), forDocument: documentRef)
                    transaction.setData([
                        "uid": user.uid,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: usernameRef)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func runUserUpdateTransaction(_ user: UserModel) async throws {
        let userRef = usersRef.document(user.uid)
        let newUsernameRef = usernamesRef.document(user.username)
        let dto = user.toDTO()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction { transaction, errorPointer in
                do {
                    let userSnapshot = try transaction.getDocument(userRef)
                    let currentUsername = userSnapshot.data()?["username"] as? String ?? ""

                    let newUsernameSnapshot = try transaction.getDocument(newUsernameRef)
                    if newUsernameSnapshot.exists {
                        let ownerUID = newUsernameSnapshot.data()?["uid"] as? String
                        if ownerUID != user.uid {
                            throw UserError.usernameTaken
                        }
                    }

                    if currentUsername != user.username {
                        if !currentUsername.isEmpty {
                            let oldUsernameRef = self.usernamesRef.document(currentUsername)
                            let oldUsernameSnapshot = try transaction.getDocument(oldUsernameRef)
                            if oldUsernameSnapshot.exists,
                               oldUsernameSnapshot.data()?["uid"] as? String == user.uid {
                                transaction.deleteDocument(oldUsernameRef)
                            }
                        }
                    }

                    transaction.setData([
                        "uid": user.uid,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: newUsernameRef)
                    transaction.setData(dto.asDictionary(), forDocument: userRef, merge: true)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func reserveUsernameForExistingUser(_ user: UserModel) async throws {
        try validateUsername(user.username)
        let usernameRef = usernamesRef.document(user.username)
        let usernameSnapshot = try await usernameRef.getDocument()
        if usernameSnapshot.exists {
            let ownerUID = usernameSnapshot.data()?["uid"] as? String
            if ownerUID != user.uid {
                throw UserError.usernameTaken
            }
            return
        }

        try await usernameRef.setData([
            "uid": user.uid,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    /// Repairs a pre-reservation-era user account in place.
    /// - If the user's existing username matches the new regex, ensures a
    ///   reservation doc exists and returns nil (caller falls back to original).
    /// - If the username is invalid (e.g. legacy users with uppercase or
    ///   unicode chars), generates a normalized replacement based on
    ///   displayName + uid suffix, writes it via `runUserUpdateTransaction`,
    ///   and returns the repaired `UserModel` so the UI sees the new handle.
    /// Throws if the repair attempt collides with another user's handle —
    /// caller treats that as "could not migrate, keep current state".
    private func migrateLegacyUserIfNeeded(_ user: UserModel) async throws -> UserModel? {
        if isUsernameValid(user.username) {
            try await reserveUsernameForExistingUser(user)
            return nil
        }

        // Username is invalid or empty — pick a normalized fallback. Append
        // a uid-derived suffix so the auto-repair almost never collides.
        let suffix = String(user.uid.prefix(6)).lowercased()
        let base = usernameBase(from: user.displayName)
        let candidate = "\(base)_\(suffix)"
        guard isUsernameValid(candidate) else { return nil }

        let repaired = UserModel(
            uid: user.uid,
            displayName: user.displayName,
            username: candidate,
            bio: user.bio,
            profileImageURL: user.profileImageURL,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
            totalSessions: user.totalSessions,
            totalClimbs: user.totalClimbs,
            highestGrade: user.highestGrade,
            highestGradeNumeric: user.highestGradeNumeric,
            isPublic: user.isPublic,
            lastSyncedAt: user.lastSyncedAt,
            homeGymOverride: user.homeGymOverride
        )
        try await runUserUpdateTransaction(repaired)
        return repaired
    }

    private func isUsernameValid(_ username: String) -> Bool {
        username.range(of: #"^[a-z0-9_]{3,20}$"#, options: .regularExpression) != nil
    }

    private func validateUsername(_ username: String) throws {
        let pattern = #"^[a-z0-9_]{3,20}$"#
        guard username.range(of: pattern, options: .regularExpression) != nil else {
            throw UserError.invalidUsername
        }
    }

    private func usernameBase(from displayName: String) -> String {
        let normalized = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return normalized.isEmpty ? "climber" : String(normalized.prefix(13))
    }

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
            lastSyncedAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            homeGymOverride: data["homeGymOverride"] as? String,
            blockedUserIds: data["blockedUserIds"] as? [String] ?? []
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
