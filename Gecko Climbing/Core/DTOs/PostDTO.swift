import Foundation

struct PostDTO: Codable, Identifiable {
    var id: String?
    let userId: String
    let userDisplayName: String
    let userProfileImageURL: String
    let sessionId: String
    let gymName: String
    let type: String
    let caption: String
    let imageURL: String?
    let likesCount: Int
    let commentsCount: Int
    let createdAt: Date
    let topGrade: String
    let topGradeNumeric: Int
    let totalClimbs: Int
    let gradeCounts: [String: Int]
    let visibility: String

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "userDisplayName": userDisplayName,
            "userProfileImageURL": userProfileImageURL,
            "sessionId": sessionId,
            "gymName": gymName,
            "type": type,
            "caption": caption,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": createdAt,
            "topGrade": topGrade,
            "topGradeNumeric": topGradeNumeric,
            "totalClimbs": totalClimbs,
            "gradeCounts": gradeCounts,
            "visibility": visibility
        ]
        if let imageURL { dict["imageURL"] = imageURL }
        return dict
    }

    func toModel() -> PostModel {
        PostModel(
            postId: id ?? UUID().uuidString,
            userId: userId,
            userDisplayName: userDisplayName,
            userProfileImageURL: userProfileImageURL,
            sessionId: sessionId,
            gymName: gymName,
            type: type,
            caption: caption,
            imageURL: imageURL,
            likesCount: likesCount,
            commentsCount: commentsCount,
            createdAt: createdAt,
            topGrade: topGrade,
            topGradeNumeric: topGradeNumeric,
            totalClimbs: totalClimbs,
            gradeCounts: gradeCounts,
            visibility: visibility
        )
    }
}

extension PostModel {
    func toDTO() -> PostDTO {
        PostDTO(
            id: postId,
            userId: userId,
            userDisplayName: userDisplayName,
            userProfileImageURL: userProfileImageURL,
            sessionId: sessionId,
            gymName: gymName,
            type: type,
            caption: caption,
            imageURL: imageURL,
            likesCount: likesCount,
            commentsCount: commentsCount,
            createdAt: createdAt,
            topGrade: topGrade,
            topGradeNumeric: topGradeNumeric,
            totalClimbs: totalClimbs,
            gradeCounts: gradeCounts,
            visibility: visibility
        )
    }
}
