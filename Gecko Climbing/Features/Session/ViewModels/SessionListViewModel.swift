import Foundation
import Observation
import SwiftData

@Observable
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
            try await sessionRepository.deleteSession(session.sessionId, context: context)
            sessions.removeAll { $0.sessionId == session.sessionId }
        } catch {
            self.error = error
        }
    }
}
