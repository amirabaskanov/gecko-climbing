import Foundation
import Observation
import PhotosUI
import SwiftUI

@Observable @MainActor
final class ProfileViewModel {
    var user: UserModel?
    var recentSessions: [SessionModel] = []
    var allSessions: [SessionModel] = []
    var isLoading = false
    var error: Error?

    // Edit fields
    var editDisplayName = ""
    var editUsername = ""
    var editBio = ""

    private let userRepository: any UserRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    private let storageRepository: any StorageRepositoryProtocol
    private let postRepository: any PostRepositoryProtocol
    private let userId: String

    init(userRepository: any UserRepositoryProtocol,
         sessionRepository: any SessionRepositoryProtocol,
         storageRepository: any StorageRepositoryProtocol,
         postRepository: any PostRepositoryProtocol,
         userId: String) {
        self.userRepository = userRepository
        self.sessionRepository = sessionRepository
        self.storageRepository = storageRepository
        self.postRepository = postRepository
        self.userId = userId
    }

    func load() async {
        isLoading = true
        async let userTask = userRepository.fetchCurrentUser()
        async let sessionsTask = sessionRepository.fetchSessions(for: userId)
        do {
            let (u, s) = try await (userTask, sessionsTask)
            user = u
            allSessions = s
            recentSessions = Array(s.prefix(10))
            editDisplayName = u.displayName
            editUsername = u.username
            editBio = u.bio
        } catch {
            self.error = error
        }
        isLoading = false
    }

    /// Consecutive weeks (ending with the current or most recent week) that have at least one session.
    var weeklyStreak: Int {
        guard !allSessions.isEmpty else { return 0 }

        let calendar = Calendar.current

        // Collect unique week identifiers (year + weekOfYear) from all sessions
        var weeksWithSessions = Set<DateComponents>()
        for session in allSessions {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            weeksWithSessions.insert(comps)
        }

        // Walk backwards from the current week
        let now = Date()
        var currentWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        var streak = 0

        // If the current week has no session, start from the previous week
        if !weeksWithSessions.contains(currentWeek) {
            guard let prevDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return 0 }
            currentWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: prevDate)
            // If that week also has no session, streak is 0
            guard weeksWithSessions.contains(currentWeek) else { return 0 }
        }

        // Count consecutive weeks going backwards
        while weeksWithSessions.contains(currentWeek) {
            streak += 1
            guard let weekStart = calendar.date(from: currentWeek),
                  let prevDate = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
            currentWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: prevDate)
        }

        return streak
    }

    var normalizedEditUsername: String {
        Self.normalizedUsername(editUsername)
    }

    var usernameValidationMessage: String? {
        let username = normalizedEditUsername
        guard username.count >= 3 else {
            return "Use at least 3 characters."
        }
        guard username.count <= 20 else {
            return "Keep it to 20 characters or fewer."
        }
        guard username.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else {
            return "Use letters, numbers, and underscores only."
        }
        return nil
    }

    var canSaveProfile: Bool {
        !editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        usernameValidationMessage == nil
    }

    func saveProfile() async -> Bool {
        guard let currentUser = user else { return false }
        guard canSaveProfile else {
            error = UserError.invalidUsername
            return false
        }

        let updatedUser = UserModel(
            uid: currentUser.uid,
            displayName: editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            username: normalizedEditUsername,
            bio: editBio.trimmingCharacters(in: .whitespacesAndNewlines),
            profileImageURL: currentUser.profileImageURL,
            followersCount: currentUser.followersCount,
            followingCount: currentUser.followingCount,
            totalSessions: currentUser.totalSessions,
            totalClimbs: currentUser.totalClimbs,
            highestGrade: currentUser.highestGrade,
            highestGradeNumeric: currentUser.highestGradeNumeric,
            isPublic: currentUser.isPublic,
            lastSyncedAt: currentUser.lastSyncedAt,
            homeGymOverride: currentUser.homeGymOverride
        )
        let nameChanged = updatedUser.displayName != currentUser.displayName
        let photoChanged = updatedUser.profileImageURL != currentUser.profileImageURL
        do {
            try await userRepository.updateUser(updatedUser)
            user = updatedUser
            editDisplayName = updatedUser.displayName
            editUsername = updatedUser.username
            editBio = updatedUser.bio
            if nameChanged || photoChanged {
                await cascadeIdentityToPosts(for: updatedUser)
            }
            return true
        } catch {
            self.error = error
            return false
        }
    }

    func uploadProfilePhoto(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let url = try await storageRepository.uploadProfilePhoto(userId: userId, imageData: data)
            user?.profileImageURL = url
            if let user {
                try await userRepository.updateUser(user)
                await cascadeIdentityToPosts(for: user)
            }
        } catch {
            self.error = error
        }
    }

    /// Push the user's current display name and profile image URL into every
    /// post they've authored. Best-effort — a cascade failure shouldn't block
    /// the profile edit since the `users/{uid}` doc has already been updated.
    private func cascadeIdentityToPosts(for user: UserModel) async {
        do {
            try await postRepository.cascadeAuthorMetadata(
                uid: user.uid,
                displayName: user.displayName,
                profileImageURL: user.profileImageURL
            )
        } catch {
            #if DEBUG
            print("[ProfileViewModel] cascadeAuthorMetadata failed: \(error.localizedDescription)")
            #endif
        }
    }

    private static func normalizedUsername(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }
}
