import Foundation
import SwiftUI

/// Generates personalized insights by comparing the current session against history.
/// Pure computation — no side effects, no network calls.
enum SessionInsightsEngine {

    /// Generate up to 3 insights for the just-finished session.
    static func generate(
        current: SessionModel,
        history: [SessionModel]
    ) -> [SessionInsight] {
        // History excludes the current session
        let past = history.filter { $0.sessionId != current.sessionId }

        var all: [SessionInsight] = []

        // Run each generator — order = priority
        if let i = newTopGrade(current: current, past: past) { all.append(i) }
        if let i = newHighestFlash(current: current, past: past) { all.append(i) }
        if let i = mostClimbsEver(current: current, past: past) { all.append(i) }
        if let i = flashRateInsight(current: current, past: past) { all.append(i) }
        if let i = sendRateInsight(current: current, past: past) { all.append(i) }
        if let i = volumeVsAverage(current: current, past: past) { all.append(i) }
        if let i = gymMilestone(current: current, past: past) { all.append(i) }
        if let i = streakInsight(current: current, past: past) { all.append(i) }
        if let i = totalSessionsMilestone(past: past) { all.append(i) }
        if let i = gradeProgressionTrend(current: current, past: past) { all.append(i) }

        // If we have nothing interesting, give encouragement
        if all.isEmpty, let i = encouragement(current: current, past: past) {
            all.append(i)
        }

        return Array(all.prefix(3))
    }

    // MARK: - Insight Generators

    /// New personal best top grade
    private static func newTopGrade(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        guard current.highestGradeNumeric >= 0 else { return nil }
        let previousBest = past.map(\.highestGradeNumeric).max() ?? -1
        guard current.highestGradeNumeric > previousBest, previousBest >= 0 else { return nil }

        return SessionInsight(
            kind: .personalBest,
            title: "New Top Grade!",
            description: "First time sending \(current.highestGrade) — up from \(VGrade.label(for: previousBest)).",
            icon: "trophy.fill",
            accentColor: .geckoFlashGold
        )
    }

    /// New highest flash
    private static func newHighestFlash(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        let currentFlashes = current.climbs.filter { $0.climbOutcome == .flash }
        guard let bestFlash = currentFlashes.max(by: { $0.gradeNumeric < $1.gradeNumeric }) else { return nil }

        let previousBestFlash = past
            .flatMap { $0.climbs.filter { $0.climbOutcome == .flash } }
            .max(by: { $0.gradeNumeric < $1.gradeNumeric })

        let prevNum = previousBestFlash?.gradeNumeric ?? -1
        guard bestFlash.gradeNumeric > prevNum, prevNum >= 0 else { return nil }

        return SessionInsight(
            kind: .personalBest,
            title: "Highest Flash!",
            description: "You flashed \(bestFlash.grade) — previous best was \(previousBestFlash?.grade ?? "none").",
            icon: "bolt.fill",
            accentColor: .geckoFlashGold
        )
    }

    /// Most climbs in a single session
    private static func mostClimbsEver(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        guard !past.isEmpty else { return nil }
        let previousMax = past.map(\.totalClimbs).max() ?? 0
        guard current.totalClimbs > previousMax, previousMax > 0 else { return nil }

        return SessionInsight(
            kind: .personalBest,
            title: "Most Climbs Ever!",
            description: "\(current.totalClimbs) climbs — you beat your record of \(previousMax).",
            icon: "flame.fill",
            accentColor: .geckoOrange
        )
    }

    /// Flash rate comparison vs personal average
    private static func flashRateInsight(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        guard current.totalClimbs >= 4 else { return nil }
        let currentRate = Double(current.flashCount) / Double(current.totalClimbs)

        let pastWithClimbs = past.filter { $0.totalClimbs >= 3 }
        guard pastWithClimbs.count >= 3 else { return nil }

        let avgRate = pastWithClimbs.reduce(0.0) { acc, s in
            acc + Double(s.flashCount) / Double(s.totalClimbs)
        } / Double(pastWithClimbs.count)

        guard currentRate > avgRate + 0.1, currentRate > 0.15 else { return nil }

        let pct = Int(currentRate * 100)
        let avgPct = Int(avgRate * 100)

        return SessionInsight(
            kind: .trend,
            title: "Flash Machine",
            description: "\(pct)% flash rate today vs your \(avgPct)% average.",
            icon: "bolt.circle.fill",
            accentColor: .geckoFlashGold
        )
    }

    /// Send rate (completion rate) comparison
    private static func sendRateInsight(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        guard current.totalClimbs >= 4 else { return nil }
        let currentRate = Double(current.completedClimbs) / Double(current.totalClimbs)

        let pastWithClimbs = past.filter { $0.totalClimbs >= 3 }
        guard pastWithClimbs.count >= 3 else { return nil }

        let avgRate = pastWithClimbs.reduce(0.0) { acc, s in
            acc + Double(s.completedClimbs) / Double(s.totalClimbs)
        } / Double(pastWithClimbs.count)

        guard currentRate > avgRate + 0.1, currentRate > 0.5 else { return nil }

        let pct = Int(currentRate * 100)

        return SessionInsight(
            kind: .trend,
            title: "High Send Rate",
            description: "You sent \(pct)% of your climbs today — above your average.",
            icon: "arrow.up.right",
            accentColor: .geckoSentGreen
        )
    }

    /// Volume compared to average
    private static func volumeVsAverage(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        guard past.count >= 3 else { return nil }
        let avg = Double(past.map(\.totalClimbs).reduce(0, +)) / Double(past.count)
        guard avg > 0 else { return nil }

        let ratio = Double(current.totalClimbs) / avg
        guard ratio >= 1.25 else { return nil }

        let pct = Int((ratio - 1) * 100)

        return SessionInsight(
            kind: .trend,
            title: "Big Session",
            description: "\(pct)% more climbs than your average session.",
            icon: "chart.bar.fill",
            accentColor: .geckoPrimary
        )
    }

    /// Gym visit milestone
    private static func gymMilestone(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        let gymSessions = past.filter { $0.gymName == current.gymName }
        let count = gymSessions.count + 1 // include current

        // Only trigger on nice milestones
        let milestones = [5, 10, 15, 20, 25, 50, 75, 100]
        guard milestones.contains(count) else { return nil }

        return SessionInsight(
            kind: .milestone,
            title: "Gym Regular",
            description: "Session #\(count) at \(current.gymName)!",
            icon: "building.2.fill",
            accentColor: .geckoPrimary
        )
    }

    /// Weekly streak
    private static func streakInsight(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        let calendar = Calendar.current
        var currentWeek = calendar.component(.weekOfYear, from: current.date)
        var currentYear = calendar.component(.yearForWeekOfYear, from: current.date)
        var streak = 1

        // Sort past sessions by date descending
        let sorted = past.sorted { $0.date > $1.date }

        for session in sorted {
            let sessionWeek = calendar.component(.weekOfYear, from: session.date)
            let sessionYear = calendar.component(.yearForWeekOfYear, from: session.date)

            if sessionWeek == currentWeek && sessionYear == currentYear {
                continue // same week, skip
            }

            // Check if it's the previous week
            var prevWeekComps = DateComponents()
            prevWeekComps.weekOfYear = currentWeek
            prevWeekComps.yearForWeekOfYear = currentYear
            if let currentWeekDate = calendar.date(from: prevWeekComps),
               let oneWeekBefore = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekDate) {
                let prevW = calendar.component(.weekOfYear, from: oneWeekBefore)
                let prevY = calendar.component(.yearForWeekOfYear, from: oneWeekBefore)
                if sessionWeek == prevW && sessionYear == prevY {
                    streak += 1
                    currentWeek = sessionWeek
                    currentYear = sessionYear
                } else {
                    break
                }
            } else {
                break
            }
        }

        let milestones = [3, 4, 5, 6, 8, 10, 12, 16, 20, 25, 30, 40, 50, 52]
        guard milestones.contains(streak) else { return nil }

        return SessionInsight(
            kind: .milestone,
            title: "\(streak) Week Streak!",
            description: "You've climbed every week for \(streak) weeks straight.",
            icon: "flame.fill",
            accentColor: .geckoOrange
        )
    }

    /// Total sessions milestone (10, 25, 50, 100, ...)
    private static func totalSessionsMilestone(past: [SessionModel]) -> SessionInsight? {
        let total = past.count + 1
        let milestones = [10, 25, 50, 75, 100, 150, 200, 250, 500]
        guard milestones.contains(total) else { return nil }

        return SessionInsight(
            kind: .milestone,
            title: "\(total) Sessions!",
            description: "You've logged \(total) climbing sessions with Gecko.",
            icon: "star.fill",
            accentColor: .geckoFlashGold
        )
    }

    /// Grade progression trend over recent sessions
    private static func gradeProgressionTrend(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        guard current.highestGradeNumeric >= 0 else { return nil }
        // Look at last 5 sessions
        let recent = Array(past.sorted { $0.date > $1.date }.prefix(5))
        guard recent.count >= 4 else { return nil }

        let recentAvg = Double(recent.compactMap { $0.highestGradeNumeric >= 0 ? $0.highestGradeNumeric : nil }.reduce(0, +))
            / Double(recent.count)

        // Look at 5 sessions before those
        let older = Array(past.sorted { $0.date > $1.date }.dropFirst(5).prefix(5))
        guard older.count >= 3 else { return nil }

        let olderAvg = Double(older.compactMap { $0.highestGradeNumeric >= 0 ? $0.highestGradeNumeric : nil }.reduce(0, +))
            / Double(older.count)

        guard recentAvg > olderAvg + 0.5 else { return nil }

        let fromGrade = VGrade.label(for: Int(olderAvg.rounded()))
        let toGrade = VGrade.label(for: Int(recentAvg.rounded()))

        return SessionInsight(
            kind: .trend,
            title: "Trending Up",
            description: "Your average top grade moved from \(fromGrade) to \(toGrade) recently.",
            icon: "arrow.up.right.circle.fill",
            accentColor: .geckoSentGreen
        )
    }

    /// Fallback encouragement for when there's nothing else
    private static func encouragement(current: SessionModel, past: [SessionModel]) -> SessionInsight? {
        if past.isEmpty {
            return SessionInsight(
                kind: .encouragement,
                title: "First Session!",
                description: "Welcome to Gecko. Keep logging to unlock personal insights.",
                icon: "hand.wave.fill",
                accentColor: .geckoPrimary
            )
        }

        if current.totalClimbs >= 1 {
            return SessionInsight(
                kind: .encouragement,
                title: "Keep Climbing",
                description: "Every session counts. You've logged \(past.count + 1) sessions so far.",
                icon: "figure.climbing",
                accentColor: .geckoPrimary
            )
        }

        return nil
    }
}
