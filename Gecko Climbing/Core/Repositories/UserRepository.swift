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
    /// Real climbers to suggest as potential follows. Excludes the current user,
    /// demo accounts, and (when possible) users already followed.
    /// Used to populate the "Climbers you might know" carousel injected into
    /// empty Following feeds and into Discover.
    func suggestedClimbers(excluding excludedUIDs: Set<String>, limit: Int) async throws -> [UserModel]
    func reconcileFollowCounts(uid: String) async throws
    func fetchNotificationPrefs(for userId: String) async throws -> NotificationPrefs
    func updateNotificationPrefs(_ prefs: NotificationPrefs, for userId: String) async throws
    func registerFCMToken(_ token: String, for userId: String) async throws
    func updateTimeZone(_ identifier: String, for userId: String) async throws
}

// MARK: - Mock Implementation
final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private let currentUserId: String
    private var users: [UserModel]
    private var followingSet: Set<String> = []

    init(currentUserId: String) {
        self.currentUserId = currentUserId
        self.users = Self.makeSeedUsers(currentUserId: currentUserId)
        // Pre-seed Kai following the rest of the cast so the Following feed
        // is populated on first launch in screenshot mode.
        if currentUserId == MockSeed.kaiUserId {
            followingSet = [
                MockSeed.rileyUserId,
                MockSeed.mayaUserId,
                MockSeed.jordanUserId,
                MockSeed.marcoUserId,
                MockSeed.naomiUserId
            ]
        }
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
        if users.contains(where: { $0.uid != user.uid && $0.username == user.username }) {
            throw UserError.usernameTaken
        }
        if let idx = users.firstIndex(where: { $0.uid == user.uid }) {
            users[idx] = user
        }
    }

    func follow(targetUID: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard !followingSet.contains(targetUID) else { return }
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

    func suggestedClimbers(excluding excludedUIDs: Set<String>, limit: Int) async throws -> [UserModel] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return users
            .filter { $0.uid != currentUserId }
            .filter { !excludedUIDs.contains($0.uid) }
            .filter { !FeedConfig.demoUserIds.contains($0.uid) }
            .sorted { $0.totalSessions > $1.totalSessions }
            .prefix(limit)
            .map { $0 }
    }

    func reconcileFollowCounts(uid: String) async throws {
        // No-op for mock
    }

    private var notificationPrefsStore: [String: NotificationPrefs] = [:]

    func fetchNotificationPrefs(for userId: String) async throws -> NotificationPrefs {
        try await Task.sleep(nanoseconds: 100_000_000)
        return notificationPrefsStore[userId] ?? .default
    }

    func updateNotificationPrefs(_ prefs: NotificationPrefs, for userId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        notificationPrefsStore[userId] = prefs
    }

    func registerFCMToken(_ token: String, for userId: String) async throws {}

    func updateTimeZone(_ identifier: String, for userId: String) async throws {}

    private static func makeSeedUsers(currentUserId: String) -> [UserModel] {
        // When running in screenshot mode the current user is Kai; otherwise
        // (regular SwiftUI previews) it's a generic preview user. Either way,
        // the rest of the cast stays the same so previews still look rich.
        let isKai = currentUserId == MockSeed.kaiUserId

        let kai = UserModel(
            uid: isKai ? currentUserId : MockSeed.kaiUserId,
            displayName: MockSeed.kaiDisplayName,
            username: "kaisends",
            bio: "SF · Dogpatch regular · projecting V8",
            profileImageURL: MockSeed.kaiAvatar,
            followersCount: 142,
            followingCount: 96,
            totalSessions: 38,
            totalClimbs: 240,
            highestGrade: "V7",
            highestGradeNumeric: 7
        )

        let riley = UserModel(
            uid: MockSeed.rileyUserId,
            displayName: MockSeed.rileyDisplayName,
            username: "rileybrooks",
            bio: "LA · Hollywood Boulders · learning to trust my feet",
            profileImageURL: MockSeed.climbIndoorFemale1,
            followersCount: 198,
            followingCount: 124,
            totalSessions: 78,
            totalClimbs: 401,
            highestGrade: "V6",
            highestGradeNumeric: 6
        )

        let maya = UserModel(
            uid: MockSeed.mayaUserId,
            displayName: MockSeed.mayaDisplayName,
            username: "mayatanaka",
            bio: "5 months in. Falling on V3s. Loving every minute.",
            followersCount: 67,
            followingCount: 92,
            totalSessions: 22,
            totalClimbs: 98,
            highestGrade: "V3",
            highestGradeNumeric: 3
        )

        let jordan = UserModel(
            uid: MockSeed.jordanUserId,
            displayName: MockSeed.jordanDisplayName,
            username: "jordanreyes",
            bio: "Boulder, CO · The Spot · here for the send energy",
            followersCount: 89,
            followingCount: 71,
            totalSessions: 41,
            totalClimbs: 187,
            highestGrade: "V4",
            highestGradeNumeric: 4
        )

        let marco = UserModel(
            uid: MockSeed.marcoUserId,
            displayName: MockSeed.marcoDisplayName,
            username: "marcopark",
            bio: "Bay Area. Prefers overhangs. Slabs respectfully.",
            profileImageURL: MockSeed.climbOutdoorMale,
            followersCount: 113,
            followingCount: 138,
            totalSessions: 52,
            totalClimbs: 246,
            highestGrade: "V5",
            highestGradeNumeric: 5
        )

        let naomi = UserModel(
            uid: MockSeed.naomiUserId,
            displayName: MockSeed.naomiDisplayName,
            username: "naomicole",
            bio: "Boston. CRG Harvard. Currently siege-training V8.",
            followersCount: 264,
            followingCount: 81,
            totalSessions: 96,
            totalClimbs: 524,
            highestGrade: "V7",
            highestGradeNumeric: 7
        )

        var users = [kai, riley, maya, jordan, marco, naomi]

        // If the current user isn't Kai (e.g. SwiftUI preview), prepend a
        // generic stub so `fetchCurrentUser()` resolves.
        if !isKai {
            users.insert(
                UserModel(
                    uid: currentUserId,
                    displayName: "Preview Climber",
                    username: "preview_climber",
                    bio: "Preview environment user",
                    followersCount: 5,
                    followingCount: 12,
                    totalSessions: 8,
                    totalClimbs: 34,
                    highestGrade: "V4",
                    highestGradeNumeric: 4
                ),
                at: 0
            )
        }

        return users
    }
}

enum UserError: LocalizedError {
    case notFound
    case invalidUsername
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "User not found."
        case .invalidUsername:
            return "Usernames must be 3-20 characters and can only use letters, numbers, and underscores."
        case .usernameTaken:
            return "That username is already taken."
        }
    }
}
