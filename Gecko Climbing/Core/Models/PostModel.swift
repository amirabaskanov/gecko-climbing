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
    /// Nil for legacy posts (field added later) — the card hides the duration
    /// stat rather than showing a fake zero.
    var sessionDurationMinutes: Int?
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
         sessionDurationMinutes: Int? = nil,
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
        self.sessionDurationMinutes = sessionDurationMinutes
        self.visibility = visibility
    }
}

// MARK: - Climb sequence (feed rendering)

/// One climb as the feed renders it: canonical grade string + outcome.
struct PostClimb: Equatable {
    let grade: String
    let outcome: ClimbOutcome
}

/// A run of identical consecutive climbs, for the expanded chip view.
struct PostClimbGroup: Identifiable {
    let grade: String
    let outcome: ClimbOutcome
    let count: Int
    let index: Int
    var id: Int { index }
}

extension PostModel {
    /// Chronological (grade, outcome) pairs. Prefers `gradeSequence` (which
    /// includes attempts); legacy posts that predate it fall back to
    /// `gradeCounts` with all climbs treated as sent. Consumers must gate the
    /// climbs UI on THIS being non-empty — gating on `gradeCounts` hides
    /// all-attempt sessions, whose gradeCounts only counts completed climbs.
    var climbSequence: [PostClimb] {
        if !gradeSequence.isEmpty {
            return gradeSequence.enumerated().map { idx, grade in
                let raw = idx < outcomeSequence.count ? outcomeSequence[idx] : ClimbOutcome.sent.rawValue
                return PostClimb(grade: grade, outcome: ClimbOutcome.fromString(raw))
            }
        }
        return gradeCounts
            .sorted { VGrade.numeric(for: $0.key) < VGrade.numeric(for: $1.key) }
            .flatMap { entry in
                Array(repeating: PostClimb(grade: entry.key, outcome: .sent), count: entry.value)
            }
    }

    /// Groups consecutive identical (grade, outcome) pairs only when the
    /// session is too long to show unbundled. A send and an attempt at the
    /// same grade never merge, so the texture reads correctly.
    func groupedChips(maxUnbundled: Int = 8) -> [PostClimbGroup] {
        let sequence = climbSequence
        if sequence.count <= maxUnbundled {
            return sequence.enumerated().map {
                PostClimbGroup(grade: $1.grade, outcome: $1.outcome, count: 1, index: $0)
            }
        }
        var groups: [PostClimbGroup] = []
        for climb in sequence {
            if let last = groups.last, last.grade == climb.grade, last.outcome == climb.outcome {
                groups[groups.count - 1] = PostClimbGroup(
                    grade: last.grade, outcome: last.outcome, count: last.count + 1, index: last.index
                )
            } else {
                groups.append(PostClimbGroup(grade: climb.grade, outcome: climb.outcome, count: 1, index: groups.count))
            }
        }
        return groups
    }

    /// Outcome tallies for the stat line, derived from the sequence.
    var outcomeTally: (sends: Int, flashes: Int, attempts: Int) {
        var sends = 0, flashes = 0, attempts = 0
        for climb in climbSequence {
            switch climb.outcome {
            case .flash:   flashes += 1
            case .sent:    sends += 1
            case .attempt: attempts += 1
            }
        }
        return (sends, flashes, attempts)
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
    let sessionDurationMinutes: Int?

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
        sessionDurationMinutes = session.durationMinutes > 0 ? session.durationMinutes : nil
    }

    /// Field map applied to a post document on edit-sync. Keys match `PostDTO`.
    var firestoreFields: [String: Any] {
        var fields: [String: Any] = [
            "gymName": gymName,
            "topGrade": topGrade,
            "topGradeNumeric": topGradeNumeric,
            "totalClimbs": totalClimbs,
            "gradeCounts": gradeCounts,
            "gradeSequence": gradeSequence,
            "outcomeSequence": outcomeSequence
        ]
        if let sessionDurationMinutes {
            fields["sessionDurationMinutes"] = sessionDurationMinutes
        }
        return fields
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
