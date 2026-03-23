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
    let isLiveSession: Bool
    let startedAt: Date?
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
            isSyncedToFirestore: true,
            isLiveSession: isLiveSession,
            startedAt: startedAt
        )
    }

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
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
            "isLiveSession": isLiveSession,
            "createdAt": createdAt
        ]
        if let startedAt { dict["startedAt"] = startedAt }
        return dict
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
            isLiveSession: isLiveSession,
            startedAt: startedAt,
            createdAt: Date()
        )
    }
}
