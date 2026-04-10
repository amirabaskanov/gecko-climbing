import Foundation
import Observation
import SwiftData

@Observable @MainActor
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
    var attempts: [ClimbModel] { climbs.filter { $0.climbOutcome == .attempt } }

    var climbSummaryText: String {
        var parts: [String] = []
        if !flashes.isEmpty { parts.append("\(flashes.count) flash\(flashes.count == 1 ? "" : "es")") }
        if !sends.isEmpty { parts.append("\(sends.count) send\(sends.count == 1 ? "" : "s")") }
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
        persistDraft()
        AnalyticsService.capture(.climbAdded, properties: [
            "grade": grade,
            "outcome": outcome.rawValue,
            "attempts": attempts
        ])
    }

    func moveClimb(from source: IndexSet, to destination: Int) {
        climbs.move(fromOffsets: source, toOffset: destination)
        persistDraft()
    }

    func removeClimb(at offsets: IndexSet) {
        climbs.remove(atOffsets: offsets)
        persistDraft()
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

        // Preserve the original loggedAt from the live-logger so chronological
        // sorts (feed pills, session detail) reflect the actual logging order.
        for climb in climbs {
            let c = ClimbModel(
                sessionId: session.sessionId,
                grade: climb.grade,
                gradeNumeric: climb.gradeNumeric,
                outcome: climb.climbOutcome,
                attempts: climb.attempts,
                loggedAt: climb.loggedAt
            )
            session.climbs.append(c)
        }
        session.updateStats()

        do {
            try await sessionRepository.createSession(session, context: context)
            clearDraft()
            AnalyticsService.capture(.sessionLogged, properties: [
                "climb_count": session.climbs.count,
                "max_grade": session.highestGrade,
                "gym": session.gymName,
                "duration_minutes": session.durationMinutes
            ])
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

// MARK: - Draft Persistence

/// Snapshot of in-progress session state, stashed in UserDefaults so climbs
/// survive if iOS kills the app while the user is logging.
struct SessionDraft: Codable {
    var startedAt: Date
    var gymName: String
    var notes: String
    var date: Date
    var durationHours: Int
    var durationMinutes: Int
    var climbs: [ClimbDraft]
    var updatedAt: Date

    struct ClimbDraft: Codable {
        var climbId: String
        var grade: String
        var gradeNumeric: Int
        var outcome: String
        var attempts: Int
        var loggedAt: Date
    }
}

extension NewSessionViewModel {
    private static let draftDefaultsKey = "active_session_draft_v1"
    // Anything older than this on restore is treated as abandoned and silently dropped.
    private static let draftMaxAge: TimeInterval = 7 * 24 * 60 * 60

    /// Returns a draft if one exists and is fresh; otherwise clears any stale draft and returns nil.
    static func loadDraft() -> SessionDraft? {
        guard let data = UserDefaults.standard.data(forKey: draftDefaultsKey),
              let draft = try? JSONDecoder().decode(SessionDraft.self, from: data) else {
            return nil
        }
        if Date().timeIntervalSince(draft.updatedAt) > draftMaxAge {
            UserDefaults.standard.removeObject(forKey: draftDefaultsKey)
            return nil
        }
        return draft
    }

    func restoreFromDraft(_ draft: SessionDraft) {
        // Freeze elapsed time at when the draft was last touched. Otherwise a session
        // restored days later would report days of "elapsed time" and save a bogus duration.
        let frozenElapsed = max(0, draft.updatedAt.timeIntervalSince(draft.startedAt))
        sessionStartedAt = Date().addingTimeInterval(-frozenElapsed)
        gymName = draft.gymName
        notes = draft.notes
        date = draft.date
        durationHours = draft.durationHours
        durationMinutes = draft.durationMinutes
        climbs = draft.climbs.map { d in
            ClimbModel(
                climbId: d.climbId,
                sessionId: "pending",
                grade: d.grade,
                gradeNumeric: d.gradeNumeric,
                outcome: ClimbOutcome.fromString(d.outcome),
                attempts: d.attempts,
                loggedAt: d.loggedAt
            )
        }
    }

    /// Writes the current session state to UserDefaults. Clears the draft if there are no climbs.
    func persistDraft() {
        guard !climbs.isEmpty else {
            clearDraft()
            return
        }
        let draft = SessionDraft(
            startedAt: sessionStartedAt,
            gymName: gymName,
            notes: notes,
            date: date,
            durationHours: durationHours,
            durationMinutes: durationMinutes,
            climbs: climbs.map { c in
                SessionDraft.ClimbDraft(
                    climbId: c.climbId,
                    grade: c.grade,
                    gradeNumeric: c.gradeNumeric,
                    outcome: c.outcome,
                    attempts: c.attempts,
                    loggedAt: c.loggedAt
                )
            },
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: Self.draftDefaultsKey)
        }
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftDefaultsKey)
    }
}
