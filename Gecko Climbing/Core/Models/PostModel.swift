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

// MARK: - Session → Post snapshot

/// The denormalized slice of a session that a feed `PostModel` caches: the
/// headline grade, climb count, gym, grade histogram, and the chronological
/// grade/outcome sequences. This is the single source of truth for that
/// projection — both post *creation* (`CelebrationView`) and post *sync after
/// a session edit* (`SessionDetailViewModel`) build it here, so the feed can
/// never drift from the session it mirrors. Computed straight from `climbs`,
/// so it does not depend on `SessionModel.updateStats()` having run.
struct PostSessionSnapshot {
    let gymName: String
    let topGrade: String
    let topGradeNumeric: Int
    let totalClimbs: Int
    let gradeCounts: [String: Int]
    let gradeSequence: [String]
    let outcomeSequence: [String]

    init(session: SessionModel) {
        // Chronological (oldest → newest) so the feed renders in logging order.
        let ordered = session.climbs.sorted { $0.loggedAt < $1.loggedAt }
        let completed = ordered.filter { $0.climbOutcome.isCompleted }
        let topCompleted = completed.max(by: { $0.gradeNumeric < $1.gradeNumeric })

        gymName = session.gymName
        topGrade = topCompleted?.grade ?? ""
        topGradeNumeric = topCompleted?.gradeNumeric ?? -1
        totalClimbs = ordered.count
        gradeCounts = Dictionary(grouping: completed, by: { $0.grade }).mapValues { $0.count }
        // Include attempts in the sequences — the feed renders them with a
        // different texture, keyed off the parallel `outcomeSequence`.
        gradeSequence = ordered.map(\.grade)
        outcomeSequence = ordered.map { $0.climbOutcome.rawValue }
    }

    /// Field map applied to a post document on edit-sync. Keys match `PostDTO`.
    var firestoreFields: [String: Any] {
        [
            "gymName": gymName,
            "topGrade": topGrade,
            "topGradeNumeric": topGradeNumeric,
            "totalClimbs": totalClimbs,
            "gradeCounts": gradeCounts,
            "gradeSequence": gradeSequence,
            "outcomeSequence": outcomeSequence
        ]
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
