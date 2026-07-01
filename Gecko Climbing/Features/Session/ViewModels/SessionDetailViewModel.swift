import Foundation
import Observation
import SwiftData

@Observable @MainActor
final class SessionDetailViewModel {
    var session: SessionModel
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let postRepository: any PostRepositoryProtocol

    init(
        session: SessionModel,
        sessionRepository: any SessionRepositoryProtocol,
        postRepository: any PostRepositoryProtocol
    ) {
        self.session = session
        self.sessionRepository = sessionRepository
        self.postRepository = postRepository
    }

    /// Chronological (oldest → newest) — first logged climb appears first.
    var sortedClimbs: [ClimbModel] {
        session.climbs.sorted { $0.loggedAt < $1.loggedAt }
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
        await persist()
    }

    func deleteClimb(_ climb: ClimbModel) async {
        session.climbs.removeAll { $0.climbId == climb.climbId }
        session.updateStats()
        await persist()
    }

    func updateClimb(_ climb: ClimbModel, grade: String, outcome: ClimbOutcome, attempts: Int) async {
        let numeric = VGrade.numeric(for: grade)
        climb.grade = grade
        climb.gradeNumeric = numeric
        climb.climbOutcome = outcome
        climb.attempts = attempts
        session.updateStats()
        await persist()
    }

    func deleteSession(context: ModelContext) async {
        do {
            // Atomic batch delete: session doc and any post that references it
            // commit together so the feed can never show a post pointing at a
            // missing session (or vice versa).
            try await sessionRepository.deleteSessionAndAssociatedPost(
                sessionId: session.sessionId,
                context: context
            )
        } catch {
            self.error = error
        }
    }

    func updateSessionDetails(gymName: String, notes: String, date: Date, durationMinutes: Int) async {
        session.gymName = gymName.trimmedGymName
        session.notes = notes
        session.date = date
        session.durationMinutes = max(0, durationMinutes)
        await persist()
    }

    /// Persist the edited session, then cascade its denormalized snapshot onto
    /// the linked feed post so the feed reflects the edit. The post sync is a
    /// no-op when the session was never shared, and leaves the post's caption,
    /// images, likes, and comments untouched. Both writes share one error path:
    /// the session save is the source of truth, the post sync mirrors it.
    private func persist() async {
        do {
            try await sessionRepository.updateSession(session)
            try await postRepository.updatePost(
                forSessionId: session.sessionId,
                snapshot: PostSessionSnapshot(session: session)
            )
        } catch {
            self.error = error
        }
    }
}
