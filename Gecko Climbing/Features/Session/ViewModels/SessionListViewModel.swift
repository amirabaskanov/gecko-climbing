import Foundation
import Observation
import SwiftData

@Observable @MainActor
final class SessionListViewModel {
    var sessions: [SessionModel] = []
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let postRepository: any PostRepositoryProtocol
    private let userId: String

    init(sessionRepository: any SessionRepositoryProtocol, postRepository: any PostRepositoryProtocol, userId: String) {
        self.sessionRepository = sessionRepository
        self.postRepository = postRepository
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
            try await postRepository.deletePostBySessionId(session.sessionId)
            sessions.removeAll { $0.sessionId == session.sessionId }
        } catch {
            self.error = error
        }
    }
}
