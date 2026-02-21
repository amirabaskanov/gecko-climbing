import Foundation
import SwiftData

@Model
final class ClimbModel {
    @Attribute(.unique) var climbId: String
    var sessionId: String
    var grade: String
    var gradeNumeric: Int
    var isCompleted: Bool
    var attempts: Int
    var outcome: String
    var notes: String
    var photoURL: String?
    var loggedAt: Date

    var climbOutcome: ClimbOutcome {
        get {
            ClimbOutcome(rawValue: outcome) ?? (isCompleted ? .sent : .fail)
        }
        set {
            outcome = newValue.rawValue
            isCompleted = newValue.isCompleted
        }
    }

    init(climbId: String = UUID().uuidString,
         sessionId: String,
         grade: String,
         gradeNumeric: Int,
         outcome: ClimbOutcome = .sent,
         attempts: Int = 1,
         notes: String = "",
         photoURL: String? = nil,
         loggedAt: Date = Date()) {
        self.climbId = climbId
        self.sessionId = sessionId
        self.grade = grade
        self.gradeNumeric = gradeNumeric
        self.outcome = outcome.rawValue
        self.isCompleted = outcome.isCompleted
        self.notes = notes
        self.photoURL = photoURL
        self.loggedAt = loggedAt
        // Enforce attempt rules
        if outcome == .flash {
            self.attempts = 1
        } else if outcome == .sent {
            self.attempts = max(attempts, 2)
        } else {
            self.attempts = max(attempts, 1)
        }
    }
}
