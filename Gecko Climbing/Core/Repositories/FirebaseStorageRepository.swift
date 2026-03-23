import Foundation
import FirebaseStorage

final class FirebaseStorageRepository: StorageRepositoryProtocol, @unchecked Sendable {
    private let storage = Storage.storage()

    func uploadClimbPhoto(userId: String, sessionId: String, climbId: String, imageData: Data) async throws -> String {
        let path = "users/\(userId)/sessions/\(sessionId)/climbs/\(climbId).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String {
        let path = "users/\(userId)/profile.jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    func uploadSessionPhoto(userId: String, sessionId: String, imageData: Data) async throws -> String {
        let photoId = UUID().uuidString.prefix(8)
        let path = "users/\(userId)/sessions/\(sessionId)/\(photoId).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    // MARK: - Private

    private func uploadImage(data: Data, path: String) async throws -> String {
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}
