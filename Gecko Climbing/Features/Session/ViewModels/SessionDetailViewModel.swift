import Foundation
import Observation
import SwiftData

@Observable @MainActor
final class SessionDetailViewModel {
    var session: SessionModel
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol

    init(session: SessionModel, sessionRepository: any SessionRepositoryProtocol) {
        self.session = session
        self.sessionRepository = sessionRepository
    }

    var sortedClimbs: [ClimbModel] {
        session.climbs.sorted { $0.loggedAt > $1.loggedAt }
    }

    var flashes: [ClimbModel] { session.climbs.filter { $0.climbOutcome == .flash } }
    var sends: [ClimbModel] { session.climbs.filter { $0.climbOutcome == .sent } }
    var fails: [ClimbModel] { session.climbs.filter { !$0.climbOutcome.isCompleted } }

    func addClimb(grade: String, outcome: ClimbOutcome, attempts: Int) async {
        let numeric = VGrade.numeric(for: grade)
        let climb = ClimbModel(
            sessionId: session.sessionId,
            grade: grade,
            gradeNumeric: numeric,
            outcome: outcome,
            attempts: attempts
        )
        session.climbs.append(climb)
        session.updateStats()
        do {
            try await sessionRepository.updateSession(session)
        } catch {
            self.error = error
        }
    }

    func deleteClimb(_ climb: ClimbModel) async {
        session.climbs.removeAll { $0.climbId == climb.climbId }
        session.updateStats()
        do {
            try await sessionRepository.updateSession(session)
        } catch {
            self.error = error
        }
    }

    func updateClimb(_ climb: ClimbModel, grade: String, outcome: ClimbOutcome, attempts: Int) async {
        let numeric = VGrade.numeric(for: grade)
        climb.grade = grade
        climb.gradeNumeric = numeric
        climb.climbOutcome = outcome
        climb.attempts = attempts
        session.updateStats()
        do {
            try await sessionRepository.updateSession(session)
        } catch {
            self.error = error
        }
    }

    func deleteSession(context: ModelContext) async {
        do {
            try await sessionRepository.deleteSession(session.sessionId, context: context)
        } catch {
            self.error = error
        }
    }

    func updateSessionDetails(gymName: String, notes: String, date: Date) async {
        session.gymName = gymName
        session.notes = notes
        session.date = date
        do {
            try await sessionRepository.updateSession(session)
        } catch {
            self.error = error
        }
    }
}
