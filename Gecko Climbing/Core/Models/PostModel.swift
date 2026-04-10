import Foundation
import SwiftData

@Model
final class PostModel {
    @Attribute(.unique) var postId: String
    var userId: String
    var userDisplayName: String
    var userProfileImageURL: String
    var sessionId: String
    var gymName: String
    var type: String
    var caption: String
    var imageURL: String?
    var imageURLs: [String]
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var isLikedByCurrentUser: Bool
    var topGrade: String
    var topGradeNumeric: Int
    var totalClimbs: Int
    var gradeCounts: [String: Int]
    var gradeSequence: [String]
    /// Parallel to `gradeSequence`: the outcome raw value ("flash"/"sent"/"attempt") for each climb.
    /// Empty for legacy posts; feed card falls back to treating all pills as sent when this is empty.
    var outcomeSequence: [String]
    var visibility: String

    init(postId: String = UUID().uuidString,
         userId: String,
         userDisplayName: String = "",
         userProfileImageURL: String = "",
         sessionId: String,
         gymName: String = "",
         type: String = "session",
         caption: String = "",
         imageURL: String? = nil,
         imageURLs: [String] = [],
         likesCount: Int = 0,
         commentsCount: Int = 0,
         createdAt: Date = Date(),
         isLikedByCurrentUser: Bool = false,
         topGrade: String = "",
         topGradeNumeric: Int = -1,
         totalClimbs: Int = 0,
         gradeCounts: [String: Int] = [:],
         gradeSequence: [String] = [],
         outcomeSequence: [String] = [],
         visibility: String = "followers") {
        self.postId = postId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.userProfileImageURL = userProfileImageURL
        self.sessionId = sessionId
        self.gymName = gymName
        self.type = type
        self.caption = caption
        self.imageURL = imageURL
        self.imageURLs = imageURLs
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.topGrade = topGrade
        self.topGradeNumeric = topGradeNumeric
        self.totalClimbs = totalClimbs
        self.gradeCounts = gradeCounts
        self.gradeSequence = gradeSequence
        self.outcomeSequence = outcomeSequence
        self.visibility = visibility
    }
}

#if DEBUG
extension PostModel {
    /// Canned post for SwiftUI previews. Avoid referencing this outside previews.
    static var preview: PostModel {
        PostModel(
            postId: "preview_post",
            userId: "preview_user",
            userDisplayName: "Alex Stone",
            userProfileImageURL: "",
            sessionId: "preview_session",
            gymName: "Movement Denver",
            type: "session",
            caption: "New personal best today 🧗",
            imageURL: nil,
            imageURLs: [],
            likesCount: 12,
            commentsCount: 3,
            createdAt: Date().addingTimeInterval(-3_600),
            isLikedByCurrentUser: false,
            topGrade: "V5",
            topGradeNumeric: 5,
            totalClimbs: 8,
            gradeCounts: ["V3": 3, "V4": 3, "V5": 2],
            gradeSequence: ["V3", "V3", "V4", "V3", "V4", "V5", "V4", "V5"],
            outcomeSequence: ["sent", "sent", "sent", "flash", "attempt", "sent", "sent", "flash"],
            visibility: "followers"
        )
    }
}
#endif
