import Foundation
import Observation

struct GradeCount: Identifiable {
    var id: String { grade }
    let grade: String
    let numeric: Int
    let count: Int
}

struct SessionProgress: Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let date: Date
    let highestGradeNumeric: Int
    let highestGrade: String
}

@Observable @MainActor
final class StatsViewModel {
    var sessions: [SessionModel] = []
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let userId: String

    init(sessionRepository: any SessionRepositoryProtocol, userId: String) {
        self.sessionRepository = sessionRepository
        self.userId = userId
    }

    // MARK: - Computed Stats
    var totalSessions: Int { sessions.count }
    var totalClimbs: Int { sessions.flatMap { $0.climbs }.count }
    var totalSends: Int { sessions.flatMap { $0.climbs }.filter { $0.isCompleted }.count }

    var highestGrade: String {
        sessions.max(by: { $0.highestGradeNumeric < $1.highestGradeNumeric })?.highestGrade ?? "—"
    }

    var highestGradeNumeric: Int {
        sessions.max(by: { $0.highestGradeNumeric < $1.highestGradeNumeric })?.highestGradeNumeric ?? -1
    }

    var gradePyramidData: [GradeCount] {
        let allSends = sessions.flatMap { $0.climbs }.filter { $0.isCompleted }
        let grouped = Dictionary(grouping: allSends, by: { $0.grade })
        return grouped.map { grade, climbs in
            GradeCount(grade: grade, numeric: VGrade.numeric(for: grade), count: climbs.count)
        }
        .sorted { $0.numeric < $1.numeric }
    }

    var progressData: [SessionProgress] {
        sessions
            .filter { $0.highestGradeNumeric >= 0 }
            .sorted { $0.date < $1.date }
            .map { SessionProgress(sessionId: $0.sessionId, date: $0.date, highestGradeNumeric: $0.highestGradeNumeric, highestGrade: $0.highestGrade) }
    }

    var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })

        while sessionDays.contains(checkDate) || (streak == 0 && sessionDays.contains(calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate)) {
            if sessionDays.contains(checkDate) {
                streak += 1
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
            if streak > 365 { break }
        }
        return streak
    }

    func loadStats() async {
        isLoading = true
        error = nil
        do {
            sessions = try await sessionRepository.fetchSessions(for: userId)
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
