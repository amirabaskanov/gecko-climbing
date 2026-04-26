import Foundation
import Observation

@Observable @MainActor
final class WeekInReviewViewModel {
    var thisWeekSessions: [SessionModel] = []
    var priorWeekSessions: [SessionModel] = []
    var allTimeHighestGradeNumeric: Int = -1
    var isLoading = false
    var error: Error?

    private let sessionRepository: any SessionRepositoryProtocol
    private let userRepository: any UserRepositoryProtocol
    private let userId: String
    private let calendar = Calendar.current

    init(
        sessionRepository: any SessionRepositoryProtocol,
        userRepository: any UserRepositoryProtocol,
        userId: String
    ) {
        self.sessionRepository = sessionRepository
        self.userRepository = userRepository
        self.userId = userId
    }

    // MARK: - Date windows

    /// Start of the 7-day window ending today (inclusive of today).
    var weekStart: Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: Date())!)
    }

    /// Start of the 7 days BEFORE the current week.
    private var priorWeekStart: Date {
        calendar.date(byAdding: .day, value: -7, to: weekStart)!
    }

    /// Last instant of the prior week (= second before weekStart).
    private var priorWeekEnd: Date {
        calendar.date(byAdding: .second, value: -1, to: weekStart)!
    }

    var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: Date()))"
    }

    // MARK: - This week aggregates

    private var allClimbs: [ClimbModel] {
        thisWeekSessions.flatMap { $0.climbs }
    }

    private var allCompletedClimbs: [ClimbModel] {
        allClimbs.filter { $0.isCompleted }
    }

    var hasActivity: Bool { !thisWeekSessions.isEmpty }

    var totalSessions: Int { thisWeekSessions.count }
    var totalClimbs: Int { allClimbs.count }
    var totalSends: Int { allCompletedClimbs.count }
    var flashCount: Int { allClimbs.filter { $0.climbOutcome == .flash }.count }
    var totalDurationMinutes: Int {
        thisWeekSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var sendRate: Double {
        guard totalClimbs > 0 else { return 0 }
        return Double(totalSends) / Double(totalClimbs)
    }

    /// Hardest grade sent this week, or nil if none.
    var hardestSendNumeric: Int? {
        allCompletedClimbs.map { $0.gradeNumeric }.max()
    }

    var hardestSendLabel: String {
        guard let n = hardestSendNumeric, n >= 0 else { return "—" }
        return VGrade.label(for: n)
    }

    /// True if this week's hardest send equals or exceeds the user's all-time highest grade.
    var isHardestSendPR: Bool {
        guard let n = hardestSendNumeric, n >= 0 else { return false }
        return n >= allTimeHighestGradeNumeric && allTimeHighestGradeNumeric >= 0
    }

    /// Set of unique calendar days the user climbed this week (start-of-day).
    var daysClimbedThisWeek: Set<Date> {
        Set(thisWeekSessions.map { calendar.startOfDay(for: $0.date) })
    }

    /// Returns 7 dates (Mon→Sun of *current* calendar week of today). For the dot row.
    /// Note: we anchor on the user's actual locale-week to read naturally.
    var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1=Sun..7=Sat
        // Shift so Monday is index 0 (1=Sun → 6, 2=Mon → 0, ...)
        let offsetFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offsetFromMonday, to: today) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// "Your wheelhouse": the V-grade you sent the most this week, with count.
    var wheelhouse: GradeCount? {
        guard !allCompletedClimbs.isEmpty else { return nil }
        let grouped = Dictionary(grouping: allCompletedClimbs, by: { $0.grade })
        let top = grouped.max(by: { $0.value.count < $1.value.count })
        guard let top else { return nil }
        return GradeCount(
            grade: top.key,
            numeric: VGrade.numeric(for: top.key),
            count: top.value.count
        )
    }

    /// Hardest grade flashed this week (if any).
    var topFlashGrade: GradeCount? {
        let flashes = allClimbs.filter { $0.climbOutcome == .flash }
        guard !flashes.isEmpty else { return nil }
        let hardest = flashes.max(by: { $0.gradeNumeric < $1.gradeNumeric })!
        return GradeCount(
            grade: hardest.grade,
            numeric: hardest.gradeNumeric,
            count: flashes.count
        )
    }

    /// Most-visited gym this week. Nil if no sessions or only blanks.
    var mostVisitedGym: (name: String, count: Int)? {
        let names = thisWeekSessions
            .map { $0.gymName }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        let grouped = Dictionary(grouping: names, by: { $0 })
        guard let top = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return (top.key, top.value.count)
    }

    /// True if more than one distinct gym this week — controls whether to show the gym card.
    var hasMultipleGyms: Bool {
        Set(thisWeekSessions.map { $0.gymName }.filter { !$0.isEmpty }).count > 1
    }

    var gradeBreakdown: [GradeCount] {
        let grouped = Dictionary(grouping: allCompletedClimbs, by: { $0.grade })
        return grouped
            .map { GradeCount(grade: $0.key, numeric: VGrade.numeric(for: $0.key), count: $0.value.count) }
            .sorted { $0.numeric < $1.numeric }
    }

    // MARK: - Prior week deltas

    private var priorClimbs: [ClimbModel] {
        priorWeekSessions.flatMap { $0.climbs }
    }

    private var priorTotalSessions: Int { priorWeekSessions.count }
    private var priorTotalDurationMinutes: Int {
        priorWeekSessions.reduce(0) { $0 + $1.durationMinutes }
    }
    private var priorHardestSendNumeric: Int? {
        priorClimbs.filter { $0.isCompleted }.map { $0.gradeNumeric }.max()
    }

    /// Sessions delta: this week - prior week.
    var sessionsDelta: Int {
        totalSessions - priorTotalSessions
    }

    /// Hardest-grade delta in V-grades: nil if either week has no sends.
    var hardestGradeDelta: Int? {
        guard let now = hardestSendNumeric, let prior = priorHardestSendNumeric else { return nil }
        return now - prior
    }

    /// Time-on-wall delta in minutes.
    var durationDeltaMinutes: Int {
        totalDurationMinutes - priorTotalDurationMinutes
    }

    /// Whether we have a meaningful prior-week to compare against.
    var hasPriorWeek: Bool { !priorWeekSessions.isEmpty }

    // MARK: - Loading

    func load() async {
        isLoading = true
        error = nil
        do {
            async let sessionsTask = sessionRepository.fetchSessions(for: userId)
            async let userTask: UserModel? = {
                do { return try await userRepository.fetchUser(uid: userId) }
                catch { return nil }
            }()

            let allSessions = try await sessionsTask
            let user = await userTask

            let weekStartLocal = weekStart
            let priorStart = priorWeekStart
            let priorEnd = priorWeekEnd

            thisWeekSessions = allSessions.filter { $0.date >= weekStartLocal }
            priorWeekSessions = allSessions.filter { $0.date >= priorStart && $0.date <= priorEnd }
            allTimeHighestGradeNumeric = user?.highestGradeNumeric ?? -1
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
