import Foundation
import UIKit

// MARK: - Protocol
protocol StorageRepositoryProtocol: AnyObject {
    func uploadClimbPhoto(userId: String, sessionId: String, climbId: String, imageData: Data) async throws -> String
    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String
    func uploadSessionPhoto(userId: String, sessionId: String, imageData: Data) async throws -> String
}

// MARK: - Mock Implementation
final class MockStorageRepository: StorageRepositoryProtocol, @unchecked Sendable {
    func uploadClimbPhoto(userId: String, sessionId: String, climbId: String, imageData: Data) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)
        return "https://picsum.photos/seed/\(climbId)/400/300"
    }

    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)
        return "https://picsum.photos/seed/\(userId)/200/200"
    }

    func uploadSessionPhoto(userId: String, sessionId: String, imageData: Data) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)
        return "https://picsum.photos/seed/\(sessionId)/600/400"
    }
}
