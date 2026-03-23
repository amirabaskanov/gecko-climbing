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
            allSessions = s
            recentSessions = Array(s.prefix(10))
            editDisplayName = u.displayName
            editBio = u.bio
            // Reconcile follow counts in background to fix any drift
            Task {
                try? await userRepository.reconcileFollowCounts(uid: userId)
                if let refreshed = try? await userRepository.fetchCurrentUser() {
                    self.user = refreshed
                }
            }
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

    func uploadProfilePhoto(item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let url = try await storageRepository.uploadProfilePhoto(userId: userId, imageData: data)
            user?.profileImageURL = url
            if let user {
                try await userRepository.updateUser(user)
            }
        } catch {
            self.error = error
        }
    }
}
