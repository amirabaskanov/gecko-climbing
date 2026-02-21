import Foundation
import Observation

@Observable
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
    var projects: [ClimbModel] { session.climbs.filter { $0.climbOutcome == .project } }
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
}
