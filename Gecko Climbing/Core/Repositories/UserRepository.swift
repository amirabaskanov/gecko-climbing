import Foundation

// MARK: - Protocol
protocol UserRepositoryProtocol: AnyObject {
    func fetchUser(uid: String) async throws -> UserModel
    func fetchCurrentUser() async throws -> UserModel
    func updateUser(_ user: UserModel) async throws
    func follow(targetUID: String) async throws
    func unfollow(targetUID: String) async throws
    func isFollowing(targetUID: String) async throws -> Bool
    func fetchFollowers(uid: String) async throws -> [UserModel]
    func fetchFollowing(uid: String) async throws -> [UserModel]
    func searchUsers(query: String) async throws -> [UserModel]
}

// MARK: - Mock Implementation
final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private let currentUserId: String
    private var users: [UserModel]
    private var followingSet: Set<String> = []

    init(currentUserId: String) {
        self.currentUserId = currentUserId
        self.users = Self.makeSeedUsers(currentUserId: currentUserId)
    }

    func fetchUser(uid: String) async throws -> UserModel {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let user = users.first(where: { $0.uid == uid }) else {
            throw UserError.notFound
        }
        return user
    }

    func fetchCurrentUser() async throws -> UserModel {
        try await Task.sleep(nanoseconds: 200_000_000)
        if let user = users.first(where: { $0.uid == currentUserId }) {
            return user
        }
        let newUser = UserModel(uid: currentUserId, displayName: "Gecko Climber", username: "gecko_climber")
        users.append(newUser)
        return newUser
    }

    func updateUser(_ user: UserModel) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        if let idx = users.firstIndex(where: { $0.uid == user.uid }) {
            users[idx] = user
        }
    }

    func follow(targetUID: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        followingSet.insert(targetUID)
        if let idx = users.firstIndex(where: { $0.uid == targetUID }) {
            users[idx].followersCount += 1
        }
    }

    func unfollow(targetUID: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        followingSet.remove(targetUID)
        if let idx = users.firstIndex(where: { $0.uid == targetUID }) {
            users[idx].followersCount = max(0, users[idx].followersCount - 1)
        }
    }

    func isFollowing(targetUID: String) async throws -> Bool {
        return followingSet.contains(targetUID)
    }

    func fetchFollowers(uid: String) async throws -> [UserModel] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return Array(users.filter { $0.uid != uid }.prefix(3))
    }

    func fetchFollowing(uid: String) async throws -> [UserModel] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return users.filter { followingSet.contains($0.uid) }
    }

    func searchUsers(query: String) async throws -> [UserModel] {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard !query.isEmpty else { return [] }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }.filter { $0.uid != currentUserId }
    }

    private static func makeSeedUsers(currentUserId: String) -> [UserModel] {
        let seedUsers: [(String, String, String, Int, Int, String, Int)] = [
            (currentUserId, "Alex Stone", "alex_stone", 5, 24, "V6", 6),
            ("friend_1", "Sam Rocks", "sam_rocks", 12, 8, "V8", 8),
            ("friend_2", "Jordan Peak", "jordan_peak", 3, 15, "V5", 5),
            ("friend_3", "Casey Wall", "casey_wall", 27, 5, "V10", 10),
            ("friend_4", "Morgan Crimp", "morgan_crimp", 8, 20, "V7", 7)
        ]
        return seedUsers.map { uid, name, username, followers, following, grade, gradeNum in
            UserModel(
                uid: uid,
                displayName: name,
                username: username,
                bio: "Climbing since \(2018 + Int.random(in: 0...5))",
                followersCount: followers,
                followingCount: following,
                totalSessions: Int.random(in: 10...80),
                totalClimbs: Int.random(in: 50...500),
                highestGrade: grade,
                highestGradeNumeric: gradeNum
            )
        }
    }
}

enum UserError: LocalizedError {
    case notFound
    var errorDescription: String? { "User not found." }
}
