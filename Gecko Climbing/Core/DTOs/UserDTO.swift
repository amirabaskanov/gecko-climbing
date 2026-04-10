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
    let notificationPrefs: NotificationPrefs

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case username
        case bio
        case profileImageURL
        case followersCount
        case followingCount
        case totalSessions
        case totalClimbs
        case highestGrade
        case highestGradeNumeric
        case isPublic
        case createdAt
        case notificationPrefs
    }

    init(
        id: String?,
        displayName: String,
        username: String,
        bio: String,
        profileImageURL: String,
        followersCount: Int,
        followingCount: Int,
        totalSessions: Int,
        totalClimbs: Int,
        highestGrade: String,
        highestGradeNumeric: Int,
        isPublic: Bool,
        createdAt: Date,
        notificationPrefs: NotificationPrefs = .default
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.totalSessions = totalSessions
        self.totalClimbs = totalClimbs
        self.highestGrade = highestGrade
        self.highestGradeNumeric = highestGradeNumeric
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.notificationPrefs = notificationPrefs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.username = try container.decode(String.self, forKey: .username)
        self.bio = try container.decode(String.self, forKey: .bio)
        self.profileImageURL = try container.decode(String.self, forKey: .profileImageURL)
        self.followersCount = try container.decode(Int.self, forKey: .followersCount)
        self.followingCount = try container.decode(Int.self, forKey: .followingCount)
        self.totalSessions = try container.decode(Int.self, forKey: .totalSessions)
        self.totalClimbs = try container.decode(Int.self, forKey: .totalClimbs)
        self.highestGrade = try container.decode(String.self, forKey: .highestGrade)
        self.highestGradeNumeric = try container.decode(Int.self, forKey: .highestGradeNumeric)
        self.isPublic = try container.decode(Bool.self, forKey: .isPublic)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.notificationPrefs = try container.decodeIfPresent(NotificationPrefs.self, forKey: .notificationPrefs) ?? .default
    }

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
