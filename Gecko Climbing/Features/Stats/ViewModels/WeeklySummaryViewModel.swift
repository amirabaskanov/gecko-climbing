import Foundation
import Observation

@Observable @MainActor
final class WeeklySummaryViewModel {
    var sessions: [SessionModel] = []
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let userId: String

    init(sessionRepository: any SessionRepositoryProtocol, userId: String) {
        self.sessionRepository = sessionRepository
        self.userId = userId
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: Date())!)
    }

    var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: Date()))"
    }

    var totalSessions: Int { sessions.count }

    private var allClimbs: [ClimbModel] {
        sessions.flatMap { $0.climbs }
    }

    var totalClimbs: Int { allClimbs.count }
    var totalSends: Int { allClimbs.filter { $0.isCompleted }.count }
    var flashCount: Int { allClimbs.filter { $0.climbOutcome == .flash }.count }

    var highestGrade: String {
        allClimbs.filter { $0.isCompleted }
            .max(by: { $0.gradeNumeric < $1.gradeNumeric })?.grade ?? "—"
    }

    var highestGradeNumeric: Int {
        allClimbs.filter { $0.isCompleted }
            .max(by: { $0.gradeNumeric < $1.gradeNumeric })?.gradeNumeric ?? -1
    }

    var totalDurationMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var sendRate: Double {
        guard totalClimbs > 0 else { return 0 }
        return Double(totalSends) / Double(totalClimbs)
    }

    var gradeBreakdown: [GradeCount] {
        let sends = allClimbs.filter { $0.isCompleted }
        let grouped = Dictionary(grouping: sends, by: { $0.grade })
        return grouped.map { grade, climbs in
            GradeCount(grade: grade, numeric: VGrade.numeric(for: grade), count: climbs.count)
        }
        .sorted { $0.numeric < $1.numeric }
    }

    var hasActivity: Bool { !sessions.isEmpty }

    func load() async {
        isLoading = true
        error = nil
        do {
            let all = try await sessionRepository.fetchSessions(for: userId)
            sessions = all.filter { $0.date >= weekStart }
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
