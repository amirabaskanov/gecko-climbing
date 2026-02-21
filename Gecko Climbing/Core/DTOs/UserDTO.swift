import Foundation

struct UserDTO: Codable, Identifiable {
    var id: String?
    let displayName: String
    let username: String
    let bio: String
    let profileImageURL: String
    let followersCount: Int
    let followingCount: Int
    let totalSessions: Int
    let totalClimbs: Int
    let highestGrade: String
    let highestGradeNumeric: Int
    let isPublic: Bool
    let createdAt: Date

    func toModel() -> UserModel {
        UserModel(
            uid: id ?? UUID().uuidString,
            displayName: displayName,
            username: username,
            bio: bio,
            profileImageURL: profileImageURL,
            followersCount: followersCount,
            followingCount: followingCount,
            totalSessions: totalSessions,
            totalClimbs: totalClimbs,
            highestGrade: highestGrade,
            highestGradeNumeric: highestGradeNumeric,
            isPublic: isPublic,
            lastSyncedAt: Date()
        )
    }

    func asDictionary() -> [String: Any] {
        [
            "displayName": displayName,
            "username": username,
            "bio": bio,
            "profileImageURL": profileImageURL,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "totalSessions": totalSessions,
            "totalClimbs": totalClimbs,
            "highestGrade": highestGrade,
            "highestGradeNumeric": highestGradeNumeric,
            "isPublic": isPublic,
            "createdAt": createdAt
        ]
    }
}

extension UserModel {
    func toDTO() -> UserDTO {
        UserDTO(
            id: uid,
            displayName: displayName,
            username: username,
            bio: bio,
            profileImageURL: profileImageURL,
            followersCount: followersCount,
            followingCount: followingCount,
            totalSessions: totalSessions,
            totalClimbs: totalClimbs,
            highestGrade: highestGrade,
            highestGradeNumeric: highestGradeNumeric,
            isPublic: isPublic,
            createdAt: lastSyncedAt
        )
    }
}
