import Foundation
import Observation

@Observable
final class ProfileViewModel {
    var user: UserModel?
    var recentSessions: [SessionModel] = []
    var isLoading = false
    var error: Error?

    // Edit fields
    var editDisplayName = ""
    var editBio = ""

    private let userRepository: any UserRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    private let storageRepository: any StorageRepositoryProtocol
    private let userId: String

    init(userRepository: any UserRepositoryProtocol,
         sessionRepository: any SessionRepositoryProtocol,
         storageRepository: any StorageRepositoryProtocol,
         userId: String) {
        self.userRepository = userRepository
        self.sessionRepository = sessionRepository
        self.storageRepository = storageRepository
        self.userId = userId
    }

    func load() async {
        isLoading = true
        async let userTask = userRepository.fetchCurrentUser()
        async let sessionsTask = sessionRepository.fetchSessions(for: userId)
        do {
            let (u, s) = try await (userTask, sessionsTask)
            user = u
            recentSessions = Array(s.prefix(10))
            editDisplayName = u.displayName
            editBio = u.bio
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func saveProfile() async {
        guard let updatedUser = user else { return }
        updatedUser.displayName = editDisplayName
        updatedUser.bio = editBio
        do {
            try await userRepository.updateUser(updatedUser)
            user = updatedUser
        } catch {
            self.error = error
        }
    }
}
