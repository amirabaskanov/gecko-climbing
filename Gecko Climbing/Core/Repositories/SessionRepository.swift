import Foundation
import SwiftData

// MARK: - Protocol
protocol SessionRepositoryProtocol: AnyObject {
    func fetchSessions(for userId: String) async throws -> [SessionModel]
    func createSession(_ session: SessionModel, context: ModelContext) async throws
    func updateSession(_ session: SessionModel) async throws
    func deleteSession(_ sessionId: String, context: ModelContext) async throws
}

// MARK: - Mock Implementation
final class MockSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    private let currentUserId: String
    private var sessions: [SessionModel] = []

    init(currentUserId: String) {
        self.currentUserId = currentUserId
        self.sessions = Self.makeSeedSessions(userId: currentUserId)
    }

    func fetchSessions(for userId: String) async throws -> [SessionModel] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return sessions
            .filter { $0.userId == userId }
            .sorted { $0.date > $1.date }
    }

    func createSession(_ session: SessionModel, context: ModelContext) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        sessions.append(session)
        session.isSyncedToFirestore = true
    }

    func updateSession(_ session: SessionModel) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        session.isSyncedToFirestore = true
    }

    func deleteSession(_ sessionId: String, context: ModelContext) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        sessions.removeAll { $0.sessionId == sessionId }
    }

    // MARK: - Seed Data
    private static func makeSeedSessions(userId: String) -> [SessionModel] {
        let grades: [(String, Int, ClimbOutcome)] = [
            ("V3", 3, .flash), ("V4", 4, .sent), ("V4", 4, .attempt),
            ("V5", 5, .sent), ("V3", 3, .flash), ("V6", 6, .attempt),
            ("V2", 2, .flash), ("V5", 5, .attempt), ("V7", 7, .attempt)
        ]

        var sessions: [SessionModel] = []

        for i in 0..<5 {
            let session = SessionModel(
                userId: userId,
                gymName: ["The Climbing Hangar", "Boulder World", "Bloc Shop", "The Arch", "Westway"][i % 5],
                date: Date().addingTimeInterval(-Double(i) * 86400 * 3),
                durationMinutes: [90, 75, 60, 120, 45][i % 5],
                notes: i == 0 ? "Great session, finally sent that V5!" : ""
            )
            for (grade, numeric, outcome) in grades.shuffled().prefix(Int.random(in: 3...6)) {
                let attempts: Int
                switch outcome {
                case .flash: attempts = 1
                case .sent: attempts = Int.random(in: 2...4)
                case .attempt: attempts = Int.random(in: 1...5)
                }
                let climb = ClimbModel(
                    sessionId: session.sessionId,
                    grade: grade,
                    gradeNumeric: numeric,
                    outcome: outcome,
                    attempts: attempts
                )
                session.climbs.append(climb)
            }
            session.updateStats()
            sessions.append(session)
        }
        return sessions
    }
}
