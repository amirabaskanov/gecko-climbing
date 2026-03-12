import Foundation
import FirebaseFirestore
import SwiftData

final class FirestoreClimbRepository: ClimbRepositoryProtocol, @unchecked Sendable {
    private let db = Firestore.firestore()

    private func climbsRef(sessionId: String) -> CollectionReference {
        db.collection("sessions").document(sessionId).collection("climbs")
    }

    func addClimb(_ climb: ClimbModel, to sessionId: String) async throws {
        let dto = climb.toDTO()
        try await climbsRef(sessionId: sessionId)
            .document(climb.climbId)
            .setData(dto.asDictionary())
    }

    func updateClimb(_ climb: ClimbModel) async throws {
        let dto = climb.toDTO()
        try await climbsRef(sessionId: climb.sessionId)
            .document(climb.climbId)
            .setData(dto.asDictionary(), merge: true)
    }

    func deleteClimb(_ climbId: String, from sessionId: String) async throws {
        try await climbsRef(sessionId: sessionId)
            .document(climbId)
            .delete()
    }

    func fetchClimbs(for sessionId: String) async throws -> [ClimbModel] {
        let snapshot = try await climbsRef(sessionId: sessionId)
            .order(by: "loggedAt")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            let outcomeString = data["outcome"] as? String ?? "attempt"
            let outcome = ClimbOutcome.fromString(outcomeString)
            return ClimbModel(
                climbId: doc.documentID,
                sessionId: data["sessionId"] as? String ?? sessionId,
                grade: data["grade"] as? String ?? "",
                gradeNumeric: data["gradeNumeric"] as? Int ?? 0,
                outcome: outcome,
                attempts: data["attempts"] as? Int ?? 1,
                notes: data["notes"] as? String ?? "",
                photoURL: data["photoURL"] as? String,
                loggedAt: (data["loggedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
}
