import Foundation
import SwiftData

@Model
final class UserModel {
    @Attribute(.unique) var uid: String
    var displayName: String
    var username: String
    var bio: String
    var profileImageURL: String
    var followersCount: Int
    var followingCount: Int
    var totalSessions: Int
    var totalClimbs: Int
    var highestGrade: String
    var highestGradeNumeric: Int
    var isPublic: Bool
    var lastSyncedAt: Date

    init(uid: String,
         displayName: String,
         username: String,
         bio: String = "",
         profileImageURL: String = "",
         followersCount: Int = 0,
         followingCount: Int = 0,
         totalSessions: Int = 0,
         totalClimbs: Int = 0,
         highestGrade: String = "",
         highestGradeNumeric: Int = -1,
         isPublic: Bool = true,
         lastSyncedAt: Date = Date()) {
        self.uid = uid
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
        self.lastSyncedAt = lastSyncedAt
    }
}
