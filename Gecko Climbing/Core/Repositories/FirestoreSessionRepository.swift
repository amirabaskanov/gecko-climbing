import Foundation
import FirebaseFirestore
import SwiftData

final class FirestoreSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    private let db = Firestore.firestore()
    private let authRepository: any AuthRepositoryProtocol

    private var sessionsRef: CollectionReference { db.collection("sessions") }

    init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func fetchSessions(for userId: String) async throws -> [SessionModel] {
        let snapshot = try await sessionsRef
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .limit(to: 100)
            .getDocuments()

        var sessions: [SessionModel] = []
        for doc in snapshot.documents {
            let data = doc.data()
            let session = decodeSession(from: data, id: doc.documentID)

            // Fetch climbs subcollection
            let climbsSnapshot = try await sessionsRef
                .document(doc.documentID)
                .collection("climbs")
                .order(by: "loggedAt")
                .getDocuments()

            session.climbs = climbsSnapshot.documents.compactMap { climbDoc in
                let climbData = climbDoc.data()
                return decodeClimb(from: climbData, id: climbDoc.documentID)
            }

            sessions.append(session)
        }

        return sessions
    }

    func createSession(_ session: SessionModel, context: ModelContext) async throws {
        let dto = session.toDTO()
        var data = dto.asDictionary()
        data["createdAt"] = FieldValue.serverTimestamp()

        let docRef = sessionsRef.document(session.sessionId)
        try await docRef.setData(data)

        // Write climbs as subcollection
        let batch = db.batch()
        for climb in session.climbs {
            let climbRef = docRef.collection("climbs").document(climb.climbId)
            batch.setData(climb.toDTO().asDictionary(), forDocument: climbRef)
        }
        try await batch.commit()

        session.isSyncedToFirestore = true

        // Update user stats
        try await updateUserStats(userId: session.userId)
    }

    func updateSession(_ session: SessionModel) async throws {
        let dto = session.toDTO()
        try await sessionsRef.document(session.sessionId).setData(dto.asDictionary(), merge: true)

        // Re-write climbs (simple replace strategy)
        let climbsRef = sessionsRef.document(session.sessionId).collection("climbs")
        let existing = try await climbsRef.getDocuments()
        let batch = db.batch()

        // Delete old climbs
        for doc in existing.documents {
            batch.deleteDocument(doc.reference)
        }

        // Write current climbs
        for climb in session.climbs {
            let ref = climbsRef.document(climb.climbId)
            batch.setData(climb.toDTO().asDictionary(), forDocument: ref)
        }

        try await batch.commit()
        session.isSyncedToFirestore = true
    }

    func deleteSession(_ sessionId: String, context: ModelContext) async throws {
        // Read the session's userId before deleting so we can update stats
        let sessionDoc = try await sessionsRef.document(sessionId).getDocument()
        let userId = sessionDoc.data()?["userId"] as? String

        // Delete climbs subcollection first
        let climbsSnapshot = try await sessionsRef.document(sessionId)
            .collection("climbs")
            .getDocuments()

        let batch = db.batch()
        for doc in climbsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(sessionsRef.document(sessionId))
        try await batch.commit()

        // Update user stats after deletion
        if let userId, !userId.isEmpty {
            try await updateUserStats(userId: userId)
        }
    }

    func deleteSessionAndAssociatedPost(sessionId: String, context: ModelContext) async throws {
        // Read the session's userId before deleting so we can update stats
        let sessionDoc = try await sessionsRef.document(sessionId).getDocument()
        let userId = sessionDoc.data()?["userId"] as? String

        // Look up any feed posts that reference this session. The post docs are the
        // user-visible "anchor" — if we delete the session but leave a post around,
        // the feed renders broken state; if we delete a post but leave the session
        // around, the user sees a session they thought they removed. Both must commit
        // atomically.
        let postsRef = db.collection("posts")
        let postsSnapshot = try await postsRef
            .whereField("sessionId", isEqualTo: sessionId)
            .getDocuments()

        // Atomic step: delete the session doc and every matching post doc in a single
        // WriteBatch. This is the integrity-critical write — all anchors live or die
        // together. (1 session + N posts; in practice N == 0 or 1, well under the 500
        // op batch limit.)
        let anchorBatch = db.batch()
        anchorBatch.deleteDocument(sessionsRef.document(sessionId))
        for postDoc in postsSnapshot.documents {
            anchorBatch.deleteDocument(postDoc.reference)
        }
        try await anchorBatch.commit()

        // Cleanup step: drain leaf subcollections (climbs under the deleted session,
        // likes under each deleted post). These are best-effort — Firestore does not
        // cascade-delete subcollections, but with their parent docs already gone the
        // orphaned leaves are unreachable from the app and safe to garbage-collect
        // later if a cleanup write fails. Failures here are logged but not rethrown
        // so the user-visible delete still appears to succeed.
        do {
            try await deleteSubcollection(parent: sessionsRef.document(sessionId), name: "climbs")
            for postDoc in postsSnapshot.documents {
                try await deleteSubcollection(parent: postsRef.document(postDoc.documentID), name: "likes")
            }
        } catch {
            print("⚠️ deleteSessionAndAssociatedPost: leaf cleanup failed (anchors already deleted): \(error)")
        }

        // Update user stats after deletion
        if let userId, !userId.isEmpty {
            try await updateUserStats(userId: userId)
        }
    }

    private func deleteSubcollection(parent: DocumentReference, name: String) async throws {
        let snapshot = try await parent.collection(name).getDocuments()
        guard !snapshot.documents.isEmpty else { return }
        // Chunk into 450-op batches to stay under the 500-op Firestore batch limit.
        let refs = snapshot.documents.map(\.reference)
        for start in stride(from: 0, to: refs.count, by: 450) {
            let end = Swift.min(start + 450, refs.count)
            let batch = db.batch()
            for ref in refs[start..<end] {
                batch.deleteDocument(ref)
            }
            try await batch.commit()
        }
    }

    // MARK: - Private

    private func decodeSession(from data: [String: Any], id: String) -> SessionModel {
        SessionModel(
            sessionId: id,
            userId: data["userId"] as? String ?? "",
            gymName: data["gymName"] as? String ?? "",
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            durationMinutes: data["durationMinutes"] as? Int ?? 0,
            notes: data["notes"] as? String ?? "",
            photoURLs: data["photoURLs"] as? [String] ?? [],
            totalClimbs: data["totalClimbs"] as? Int ?? 0,
            completedClimbs: data["completedClimbs"] as? Int ?? 0,
            highestGrade: data["highestGrade"] as? String ?? "",
            highestGradeNumeric: data["highestGradeNumeric"] as? Int ?? 0,
            isSyncedToFirestore: true,
            isLiveSession: data["isLiveSession"] as? Bool ?? false,
            startedAt: (data["startedAt"] as? Timestamp)?.dateValue()
        )
    }

    private func decodeClimb(from data: [String: Any], id: String) -> ClimbModel {
        let outcomeString = data["outcome"] as? String ?? "attempt"
        let outcome = ClimbOutcome.fromString(outcomeString)
        return ClimbModel(
            climbId: id,
            sessionId: data["sessionId"] as? String ?? "",
            grade: data["grade"] as? String ?? "",
            gradeNumeric: data["gradeNumeric"] as? Int ?? 0,
            outcome: outcome,
            attempts: data["attempts"] as? Int ?? 1,
            notes: data["notes"] as? String ?? "",
            photoURL: data["photoURL"] as? String,
            loggedAt: (data["loggedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private func updateUserStats(userId: String) async throws {
        let sessions = try await fetchSessions(for: userId)
        let totalSessions = sessions.count
        let totalClimbs = sessions.reduce(0) { $0 + $1.totalClimbs }
        let highestGradeNumeric = sessions.map(\.highestGradeNumeric).max() ?? 0
        let highestGrade = highestGradeNumeric > 0 ? "V\(highestGradeNumeric)" : ""

        try await db.collection("users").document(userId).setData([
            "totalSessions": totalSessions,
            "totalClimbs": totalClimbs,
            "highestGrade": highestGrade,
            "highestGradeNumeric": highestGradeNumeric
        ], merge: true)
    }
}
