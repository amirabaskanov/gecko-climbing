import Foundation
import SwiftData

@Model
final class SessionModel {
    @Attribute(.unique) var sessionId: String
    var userId: String
    var gymName: String
    var date: Date
    var durationMinutes: Int
    var notes: String
    var photoURLs: [String]
    var totalClimbs: Int
    var completedClimbs: Int
    var highestGrade: String
    var highestGradeNumeric: Int
    var isSyncedToFirestore: Bool
    var isLiveSession: Bool
    var startedAt: Date?
    @Relationship(deleteRule: .cascade) var climbs: [ClimbModel]

    init(sessionId: String = UUID().uuidString,
         userId: String,
         gymName: String,
         date: Date = Date(),
         durationMinutes: Int = 0,
         notes: String = "",
         photoURLs: [String] = [],
         totalClimbs: Int = 0,
         completedClimbs: Int = 0,
         highestGrade: String = "",
         highestGradeNumeric: Int = -1,
         isSyncedToFirestore: Bool = false,
         isLiveSession: Bool = false,
         startedAt: Date? = nil) {
        self.sessionId = sessionId
        self.userId = userId
        self.gymName = gymName
        self.date = date
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.photoURLs = photoURLs
        self.totalClimbs = totalClimbs
        self.completedClimbs = completedClimbs
        self.highestGrade = highestGrade
        self.highestGradeNumeric = highestGradeNumeric
        self.isSyncedToFirestore = isSyncedToFirestore
        self.isLiveSession = isLiveSession
        self.startedAt = startedAt
        self.climbs = []
    }

    func updateStats() {
        totalClimbs = climbs.count
        completedClimbs = climbs.filter { $0.climbOutcome.isCompleted }.count
        let maxGrade = climbs.filter { $0.climbOutcome.isCompleted }.max(by: { $0.gradeNumeric < $1.gradeNumeric })
        highestGrade = maxGrade?.grade ?? ""
        highestGradeNumeric = maxGrade?.gradeNumeric ?? -1
    }

    var flashCount: Int { climbs.filter { $0.climbOutcome == .flash }.count }
    var sentCount: Int { climbs.filter { $0.climbOutcome == .sent }.count }
    var projectCount: Int { climbs.filter { $0.climbOutcome == .project }.count }
    var failCount: Int { climbs.filter { $0.climbOutcome == .fail }.count }
}
