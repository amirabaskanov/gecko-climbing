import Foundation
import Observation
import SwiftData

@Observable
final class NewSessionViewModel {
    // Form fields
    var gymName = ""
    var notes = ""
    var date = Date()
    var durationHours = 1
    var durationMinutes = 30

    // Climbs logged during session
    var climbs: [ClimbModel] = []

    // State
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let userId: String

    var totalDurationMinutes: Int {
        durationHours * 60 + durationMinutes
    }

    var flashes: [ClimbModel] { climbs.filter { $0.climbOutcome == .flash } }
    var sends: [ClimbModel] { climbs.filter { $0.climbOutcome == .sent } }
    var projects: [ClimbModel] { climbs.filter { $0.climbOutcome == .project } }
    var fails: [ClimbModel] { climbs.filter { $0.climbOutcome == .fail } }

    var climbSummaryText: String {
        var parts: [String] = []
        if !flashes.isEmpty { parts.append("\(flashes.count) flash\(flashes.count == 1 ? "" : "es")") }
        if !sends.isEmpty { parts.append("\(sends.count) send\(sends.count == 1 ? "" : "s")") }
        if !projects.isEmpty { parts.append("\(projects.count) project\(projects.count == 1 ? "" : "s")") }
        if !fails.isEmpty { parts.append("\(fails.count) fail\(fails.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "No climbs" : parts.joined(separator: ", ")
    }

    init(sessionRepository: any SessionRepositoryProtocol, userId: String) {
        self.sessionRepository = sessionRepository
        self.userId = userId
    }

    func addClimb(grade: String, outcome: ClimbOutcome, attempts: Int) {
        let numeric = VGrade.numeric(for: grade)
        let climb = ClimbModel(
            sessionId: "pending",
            grade: grade,
            gradeNumeric: numeric,
            outcome: outcome,
            attempts: attempts
        )
        climbs.insert(climb, at: 0)
    }

    func removeClimb(at offsets: IndexSet) {
        climbs.remove(atOffsets: offsets)
    }

    func saveSession(context: ModelContext) async -> SessionModel? {
        guard !gymName.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = ValidationError.gymNameRequired
            return nil
        }
        isLoading = true

        let session = SessionModel(
            userId: userId,
            gymName: gymName,
            date: date,
            durationMinutes: totalDurationMinutes,
            notes: notes
        )

        for climb in climbs {
            let c = ClimbModel(
                sessionId: session.sessionId,
                grade: climb.grade,
                gradeNumeric: climb.gradeNumeric,
                outcome: climb.climbOutcome,
                attempts: climb.attempts
            )
            session.climbs.append(c)
        }
        session.updateStats()

        do {
            try await sessionRepository.createSession(session, context: context)
            isLoading = false
            return session
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
}

enum ValidationError: LocalizedError {
    case gymNameRequired
    var errorDescription: String? { "Please enter the gym name." }
}
