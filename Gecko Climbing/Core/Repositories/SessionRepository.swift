import Foundation
import SwiftData

// MARK: - Protocol
protocol SessionRepositoryProtocol: AnyObject {
    func fetchSessions(for userId: String) async throws -> [SessionModel]
    func createSession(_ session: SessionModel, context: ModelContext) async throws
    func updateSession(_ session: SessionModel) async throws
    func deleteSession(_ sessionId: String, context: ModelContext) async throws

    /// Atomically delete a session and any feed post that references it.
    /// Implementations must commit both deletions in a single Firestore batch
    /// (or transaction) so callers never observe an intermediate state where a
    /// post is orphaned (pointing at a missing session) or vice versa. If no
    /// post references the session, only the session is deleted.
    func deleteSessionAndAssociatedPost(sessionId: String, context: ModelContext) async throws

    func fetchRecentGymNames(for userId: String) async throws -> [String]
}

extension SessionRepositoryProtocol {
    func fetchRecentGymNames(for userId: String) async throws -> [String] {
        let sessions = try await fetchSessions(for: userId)
        let gyms = sessions.sorted { $0.date > $1.date }.map(\.gymName).filter { !$0.isEmpty }
        var seen = Set<String>()
        return gyms.filter { seen.insert($0).inserted }
    }
}

// MARK: - Mock Implementation
final class MockSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    private let currentUserId: String
    private var sessions: [SessionModel] = []

    init(currentUserId: String) {
        self.currentUserId = currentUserId
        self.sessions = Self.makeSeedSessions(userId: currentUserId)
    }

    func fetchSessions(for userId: String) async throws -> [SessionModel] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return sessions
            .filter { $0.userId == userId }
            .sorted { $0.date > $1.date }
    }

    func createSession(_ session: SessionModel, context: ModelContext) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        sessions.append(session)
        session.isSyncedToFirestore = true
    }

    func updateSession(_ session: SessionModel) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        session.isSyncedToFirestore = true
    }

    func deleteSession(_ sessionId: String, context: ModelContext) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        sessions.removeAll { $0.sessionId == sessionId }
    }

    func deleteSessionAndAssociatedPost(sessionId: String, context: ModelContext) async throws {
        // Mock has no post repository handle, so just remove the session.
        // The real Firestore implementation atomically deletes both docs.
        try await Task.sleep(nanoseconds: 200_000_000)
        sessions.removeAll { $0.sessionId == sessionId }
    }

    // MARK: - Seed Data
    private static func makeSeedSessions(userId: String) -> [SessionModel] {
        if userId == MockSeed.kaiUserId {
            return makeKaiSessions(userId: userId)
        }
        return makePreviewSessions(userId: userId)
    }

    /// Kai's session history. Five featured sessions in the past two weeks
    /// (each matching a real post in `MockPostRepository`) plus ~25 background
    /// sessions over 13 weeks so the activity heatmap fills out and "all-time"
    /// stats look lived-in.
    private static func makeKaiSessions(userId: String) -> [SessionModel] {
        struct Plan {
            let gym: String
            let hoursAgo: Double
            let duration: Int
            let notes: String
            let arc: [(String, ClimbOutcome)]
        }

        // MARK: Featured (recent, post-linked)
        let featured: [Plan] = [
            Plan(
                gym: "Dogpatch Boulders",
                hoursAgo: 4,
                duration: 95,
                notes: "Sent V7 in the cave. Heel toe locked in after 5 attempts. V8 next session.",
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .flash),
                    ("V4", .sent), ("V5", .flash), ("V5", .sent),
                    ("V6", .sent), ("V7", .sent), ("V7", .attempt),
                    ("V8", .attempt), ("V4", .sent), ("V3", .flash)
                ]
            ),
            Plan(
                gym: "Dogpatch Boulders",
                hoursAgo: 50,
                duration: 80,
                notes: "Compression V6 in the back room. Arms cooked.",
                arc: [
                    ("V1", .flash), ("V3", .flash), ("V4", .flash),
                    ("V5", .flash), ("V5", .sent), ("V6", .attempt),
                    ("V6", .attempt), ("V6", .sent), ("V4", .flash)
                ]
            ),
            Plan(
                gym: "Hollywood Boulders",
                hoursAgo: 122,
                duration: 105,
                notes: "Visiting Riley in LA. Their V6 setting is wild.",
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .sent),
                    ("V5", .flash), ("V5", .sent), ("V6", .sent),
                    ("V6", .attempt), ("V7", .attempt), ("V5", .sent),
                    ("V3", .flash)
                ]
            ),
            Plan(
                gym: "Dogpatch Boulders",
                hoursAgo: 196,
                duration: 55,
                notes: "Lunch session. Movement only.",
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .flash),
                    ("V4", .sent), ("V5", .sent)
                ]
            ),
            Plan(
                gym: "CRG Harvard Square",
                hoursAgo: 340,
                duration: 110,
                notes: "Boston trip with Naomi. CRG sets hard.",
                arc: [
                    ("V2", .flash), ("V3", .flash), ("V4", .sent),
                    ("V5", .flash), ("V5", .sent), ("V6", .sent),
                    ("V6", .sent), ("V7", .attempt), ("V7", .attempt),
                    ("V5", .sent), ("V4", .flash), ("V3", .flash)
                ]
            )
        ]

        // MARK: Background (older, padding the heatmap)
        // Two-to-three sessions per week stretching back 13 weeks. Grades stay
        // in Kai's wheelhouse (V3-V6 mostly, occasional V2 warm-ups, sporadic
        // V7 attempts) so the long-term trend matches the featured sessions.
        let backgroundArcs: [[(String, ClimbOutcome)]] = [
            [("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .sent), ("V6", .attempt), ("V5", .sent), ("V3", .flash)],
            [("V1", .flash), ("V3", .flash), ("V4", .flash), ("V5", .flash), ("V5", .sent), ("V6", .sent), ("V6", .attempt)],
            [("V3", .flash), ("V4", .sent), ("V4", .sent), ("V5", .sent), ("V5", .attempt), ("V4", .flash)],
            [("V2", .flash), ("V3", .flash), ("V4", .flash), ("V5", .sent), ("V6", .sent), ("V6", .sent), ("V7", .attempt), ("V4", .flash)],
            [("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .flash), ("V5", .sent), ("V3", .flash)],
            [("V1", .flash), ("V2", .flash), ("V3", .sent), ("V4", .sent), ("V5", .attempt), ("V4", .sent)],
            [("V3", .flash), ("V4", .flash), ("V5", .sent), ("V6", .sent), ("V6", .attempt), ("V5", .sent), ("V4", .flash)],
            [("V2", .flash), ("V3", .flash), ("V4", .sent), ("V4", .sent), ("V5", .flash), ("V5", .sent)],
            [("V3", .flash), ("V4", .flash), ("V5", .flash), ("V5", .sent), ("V6", .sent), ("V6", .sent)],
            [("V1", .flash), ("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .sent), ("V5", .attempt)],
            [("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .sent), ("V6", .attempt), ("V6", .attempt), ("V5", .sent), ("V3", .flash)],
            [("V3", .flash), ("V4", .sent), ("V5", .sent), ("V6", .attempt), ("V6", .sent)],
            [("V2", .flash), ("V3", .sent), ("V4", .sent), ("V5", .sent), ("V5", .sent), ("V4", .flash)],
            [("V1", .flash), ("V2", .flash), ("V3", .flash), ("V4", .flash), ("V5", .sent), ("V6", .attempt)],
            [("V3", .flash), ("V4", .sent), ("V5", .sent), ("V5", .sent), ("V6", .sent)],
            [("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .attempt), ("V5", .sent), ("V4", .flash)],
            [("V3", .flash), ("V4", .flash), ("V5", .flash), ("V6", .sent), ("V7", .attempt), ("V5", .sent)],
            [("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .sent), ("V6", .sent), ("V4", .flash)],
            [("V1", .flash), ("V3", .flash), ("V4", .sent), ("V5", .flash), ("V5", .sent)],
            [("V3", .flash), ("V4", .flash), ("V5", .sent), ("V5", .sent), ("V6", .attempt), ("V6", .sent)],
            [("V2", .flash), ("V3", .sent), ("V4", .sent), ("V5", .attempt), ("V4", .sent), ("V3", .flash)],
            [("V3", .flash), ("V4", .sent), ("V5", .sent), ("V6", .sent), ("V6", .sent), ("V5", .flash)],
            [("V2", .flash), ("V3", .flash), ("V4", .flash), ("V5", .sent), ("V5", .attempt)],
            [("V1", .flash), ("V2", .flash), ("V3", .flash), ("V4", .sent), ("V5", .sent), ("V6", .sent)],
            [("V3", .flash), ("V4", .sent), ("V4", .sent), ("V5", .sent), ("V6", .attempt), ("V5", .sent), ("V3", .flash)]
        ]

        let backgroundGyms = [
            "Dogpatch Boulders", "Dogpatch Boulders", "Dogpatch Boulders",
            "Pacific Pipe", "Dogpatch Boulders", "Dogpatch Boulders",
            "Mission Cliffs"
        ]

        // First background session is at hour 14*24 (~14 days ago, just after
        // the oldest featured session). Spread over 13 weeks at a 2-3 per week
        // cadence to fill the heatmap.
        let weekSpread: [Double] = [
            16 * 24, 17 * 24, 19 * 24,           // week 3
            21 * 24, 23 * 24, 25 * 24,           // week 4
            27 * 24, 29 * 24,                    // week 5
            32 * 24, 34 * 24, 36 * 24,           // week 6
            38 * 24, 41 * 24,                    // week 7
            44 * 24, 47 * 24,                    // week 8
            50 * 24, 52 * 24, 55 * 24,           // week 9
            58 * 24, 61 * 24,                    // week 10
            65 * 24, 68 * 24,                    // week 11
            72 * 24, 76 * 24,                    // week 12
            82 * 24                              // week 13
        ]

        let background: [Plan] = backgroundArcs.enumerated().map { idx, arc in
            Plan(
                gym: backgroundGyms[idx % backgroundGyms.count],
                hoursAgo: weekSpread[idx % weekSpread.count],
                duration: [60, 75, 90, 100, 50, 80, 65, 70][idx % 8],
                notes: "",
                arc: arc
            )
        }

        return (featured + background).map { plan in
            let session = SessionModel(
                userId: userId,
                gymName: plan.gym,
                date: Date().addingTimeInterval(-plan.hoursAgo * 3600),
                durationMinutes: plan.duration,
                notes: plan.notes
            )
            for (idx, step) in plan.arc.enumerated() {
                let attempts: Int
                switch step.1 {
                case .flash: attempts = 1
                case .sent: attempts = Int.random(in: 2...4)
                case .attempt: attempts = Int.random(in: 2...5)
                }
                let climb = ClimbModel(
                    sessionId: session.sessionId,
                    grade: step.0,
                    gradeNumeric: VGrade.numeric(for: step.0),
                    outcome: step.1,
                    attempts: attempts,
                    loggedAt: session.date.addingTimeInterval(Double(idx) * Double(plan.duration * 60) / Double(plan.arc.count))
                )
                session.climbs.append(climb)
            }
            session.updateStats()
            return session
        }
    }

    /// Generic randomized seed used for SwiftUI previews — kept around so
    /// previews still render content for non-Kai mock users.
    private static func makePreviewSessions(userId: String) -> [SessionModel] {
        let grades: [(String, Int, ClimbOutcome)] = [
            ("V3", 3, .flash), ("V4", 4, .sent), ("V4", 4, .attempt),
            ("V5", 5, .sent), ("V3", 3, .flash), ("V6", 6, .attempt),
            ("V2", 2, .flash), ("V5", 5, .attempt), ("V7", 7, .attempt)
        ]

        var sessions: [SessionModel] = []

        for i in 0..<5 {
            let session = SessionModel(
                userId: userId,
                gymName: ["The Climbing Hangar", "Boulder World", "Bloc Shop", "The Arch", "Westway"][i % 5],
                date: Date().addingTimeInterval(-Double(i) * 86400 * 3),
                durationMinutes: [90, 75, 60, 120, 45][i % 5],
                notes: i == 0 ? "Great session, finally sent that V5!" : ""
            )
            for (grade, numeric, outcome) in grades.shuffled().prefix(Int.random(in: 3...6)) {
                let attempts: Int
                switch outcome {
                case .flash: attempts = 1
                case .sent: attempts = Int.random(in: 2...4)
                case .attempt: attempts = Int.random(in: 1...5)
                }
                let climb = ClimbModel(
                    sessionId: session.sessionId,
                    grade: grade,
                    gradeNumeric: numeric,
                    outcome: outcome,
                    attempts: attempts
                )
                session.climbs.append(climb)
            }
            session.updateStats()
            sessions.append(session)
        }
        return sessions
    }
}
