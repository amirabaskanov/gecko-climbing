import Foundation

struct ClimbDTO: Codable, Identifiable {
    var id: String?
    let sessionId: String
    let grade: String
    let gradeNumeric: Int
    let isCompleted: Bool
    let attempts: Int
    let outcome: String
    let notes: String
    let photoURL: String?
    let loggedAt: Date

    func toModel() -> ClimbModel {
        let climbOutcome = ClimbOutcome.fromString(outcome)
        return ClimbModel(
            climbId: id ?? UUID().uuidString,
            sessionId: sessionId,
            grade: grade,
            gradeNumeric: gradeNumeric,
            outcome: climbOutcome,
            attempts: attempts,
            notes: notes,
            photoURL: photoURL,
            loggedAt: loggedAt
        )
    }

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "sessionId": sessionId,
            "grade": grade,
            "gradeNumeric": gradeNumeric,
            "isCompleted": isCompleted,
            "attempts": attempts,
            "outcome": outcome,
            "notes": notes,
            "loggedAt": loggedAt
        ]
        if let photoURL { dict["photoURL"] = photoURL }
        return dict
    }
}

extension ClimbModel {
    func toDTO() -> ClimbDTO {
        ClimbDTO(
            id: climbId,
            sessionId: sessionId,
            grade: grade,
            gradeNumeric: gradeNumeric,
            isCompleted: isCompleted,
            attempts: attempts,
            outcome: outcome,
            notes: notes,
            photoURL: photoURL,
            loggedAt: loggedAt
        )
    }
}
