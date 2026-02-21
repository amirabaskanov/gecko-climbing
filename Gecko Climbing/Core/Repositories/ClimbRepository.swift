import Foundation
import SwiftData

// MARK: - Protocol
protocol ClimbRepositoryProtocol: AnyObject {
    func addClimb(_ climb: ClimbModel, to sessionId: String) async throws
    func updateClimb(_ climb: ClimbModel) async throws
    func deleteClimb(_ climbId: String, from sessionId: String) async throws
    func fetchClimbs(for sessionId: String) async throws -> [ClimbModel]
}

// MARK: - Mock Implementation
final class MockClimbRepository: ClimbRepositoryProtocol, @unchecked Sendable {
    private var climbs: [ClimbModel] = []

    func addClimb(_ climb: ClimbModel, to sessionId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        climbs.append(climb)
    }

    func updateClimb(_ climb: ClimbModel) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    func deleteClimb(_ climbId: String, from sessionId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        climbs.removeAll { $0.climbId == climbId }
    }

    func fetchClimbs(for sessionId: String) async throws -> [ClimbModel] {
        return climbs.filter { $0.sessionId == sessionId }
    }
}
