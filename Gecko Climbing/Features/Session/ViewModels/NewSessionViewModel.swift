import Foundation
import Observation
import SwiftData

@Observable
final class NewSessionViewModel {
    // Form fields (deferred to post-save)
    var gymName = ""
    var notes = ""
    var date = Date()
    var durationHours = 1
    var durationMinutes = 30

    // Auto-timer
    var sessionStartedAt: Date = Date()

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

    /// Auto-calculated elapsed seconds since session started
    var elapsedSeconds: Int {
        Int(Date().timeIntervalSince(sessionStartedAt))
    }

    /// Auto-calculated elapsed minutes since session started
    var elapsedMinutes: Int {
        elapsedSeconds / 60
    }

    /// Formatted elapsed time string for nav bar display (m:ss or h:mm:ss)
    var elapsedTimeFormatted: String {
        let total = elapsedSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var flashes: [ClimbModel] { climbs.filter { $0.climbOutcome == .flash } }
    var sends: [ClimbModel] { climbs.filter { $0.climbOutcome == .sent } }
    var projects: [ClimbModel] { climbs.filter { $0.climbOutcome == .project } }
    var attempts: [ClimbModel] { climbs.filter { $0.climbOutcome == .attempt } }

    var climbSummaryText: String {
        var parts: [String] = []
        if !flashes.isEmpty { parts.append("\(flashes.count) flash\(flashes.count == 1 ? "" : "es")") }
        if !sends.isEmpty { parts.append("\(sends.count) send\(sends.count == 1 ? "" : "s")") }
        if !projects.isEmpty { parts.append("\(projects.count) project\(projects.count == 1 ? "" : "s")") }
        if !attempts.isEmpty { parts.append("\(attempts.count) attempt\(attempts.count == 1 ? "" : "s")") }
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

    func moveClimb(from source: IndexSet, to destination: Int) {
        climbs.move(fromOffsets: source, toOffset: destination)
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

        let finalDuration = elapsedMinutes > 0 ? elapsedMinutes : totalDurationMinutes

        let session = SessionModel(
            userId: userId,
            gymName: gymName,
            date: date,
            durationMinutes: finalDuration,
            notes: notes,
            startedAt: sessionStartedAt
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
