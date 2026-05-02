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

struct OutcomeShare: Identifiable {
    var id: ClimbOutcome { outcome }
    let outcome: ClimbOutcome
    let count: Int
    let total: Int
    var fraction: Double { total > 0 ? Double(count) / Double(total) : 0 }
}

struct GymCount: Identifiable {
    var id: String { name }
    let name: String
    let sessionCount: Int
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

    var totalDurationMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Distribution across the three outcomes. Always returns 3 entries
    /// (zero counts included) so the donut layout is stable.
    var outcomeDistribution: [OutcomeShare] {
        let allClimbs = sessions.flatMap { $0.climbs }
        let total = allClimbs.count
        let grouped = Dictionary(grouping: allClimbs, by: { $0.climbOutcome })
        return ClimbOutcome.allCases.map { outcome in
            OutcomeShare(
                outcome: outcome,
                count: grouped[outcome]?.count ?? 0,
                total: total
            )
        }
    }

    /// Top gyms by session count, capped at 3. Skips empty gym names.
    var topGyms: [GymCount] {
        let grouped = Dictionary(grouping: sessions, by: { $0.gymName })
            .filter { !$0.key.isEmpty }
        return grouped
            .map { GymCount(name: $0.key, sessionCount: $0.value.count) }
            .sorted { $0.sessionCount > $1.sessionCount }
            .prefix(3)
            .map { $0 }
    }

    /// Climb count per calendar day, used to drive the activity heatmap.
    /// Keyed by `startOfDay` for the day a climb was logged.
    var dailyClimbCounts: [Date: Int] {
        let calendar = Calendar.current
        let allClimbs = sessions.flatMap { $0.climbs }
        return Dictionary(grouping: allClimbs, by: { calendar.startOfDay(for: $0.loggedAt) })
            .mapValues { $0.count }
    }

    var hasAnyData: Bool { !sessions.isEmpty }

    /// Earliest session date — drives "Climbing since X" copy on the share card.
    var firstSessionDate: Date? {
        sessions.min(by: { $0.date < $1.date })?.date
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
