import Foundation
import Observation
import SwiftData

@Observable @MainActor
final class SessionListViewModel {
    var sessions: [SessionModel] = []
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let userId: String

    init(sessionRepository: any SessionRepositoryProtocol, userId: String) {
        self.sessionRepository = sessionRepository
        self.userId = userId
    }

    func loadSessions() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            sessions = try await sessionRepository.fetchSessions(for: userId)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func deleteSession(_ session: SessionModel, context: ModelContext) async {
        do {
            // Atomic batch delete: session doc and any post that references it commit
            // together. Replaces the previous two-call sequence which could orphan
            // either side on partial failure (see commit 673205d).
            try await sessionRepository.deleteSessionAndAssociatedPost(
                sessionId: session.sessionId,
                context: context
            )
            sessions.removeAll { $0.sessionId == session.sessionId }
        } catch {
            self.error = error
        }
    }
}
