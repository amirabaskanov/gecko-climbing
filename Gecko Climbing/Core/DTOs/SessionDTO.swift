import Foundation

struct SessionDTO: Codable, Identifiable {
    var id: String?
    let userId: String
    let gymName: String
    let date: Date
    let durationMinutes: Int
    let notes: String
    let photoURLs: [String]
    let totalClimbs: Int
    let completedClimbs: Int
    let highestGrade: String
    let highestGradeNumeric: Int
    let createdAt: Date

    func toModel() -> SessionModel {
        SessionModel(
            sessionId: id ?? UUID().uuidString,
            userId: userId,
            gymName: gymName,
            date: date,
            durationMinutes: durationMinutes,
            notes: notes,
            photoURLs: photoURLs,
            totalClimbs: totalClimbs,
            completedClimbs: completedClimbs,
            highestGrade: highestGrade,
            highestGradeNumeric: highestGradeNumeric,
            isSyncedToFirestore: true
        )
    }

    func asDictionary() -> [String: Any] {
        [
            "userId": userId,
            "gymName": gymName,
            "date": date,
            "durationMinutes": durationMinutes,
            "notes": notes,
            "photoURLs": photoURLs,
            "totalClimbs": totalClimbs,
            "completedClimbs": completedClimbs,
            "highestGrade": highestGrade,
            "highestGradeNumeric": highestGradeNumeric,
            "createdAt": createdAt
        ]
    }
}

extension SessionModel {
    func toDTO() -> SessionDTO {
        SessionDTO(
            id: sessionId,
            userId: userId,
            gymName: gymName,
            date: date,
            durationMinutes: durationMinutes,
            notes: notes,
            photoURLs: photoURLs,
            totalClimbs: totalClimbs,
            completedClimbs: completedClimbs,
            highestGrade: highestGrade,
            highestGradeNumeric: highestGradeNumeric,
            createdAt: Date()
        )
    }
}
