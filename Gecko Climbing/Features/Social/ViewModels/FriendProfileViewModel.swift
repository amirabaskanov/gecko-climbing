import Foundation
import Observation

@Observable @MainActor
final class FriendProfileViewModel {
    var user: UserModel?
    var sessions: [SessionModel] = []
    var isFollowing = false
    var isLoading = false
    var error: Error?
    /// Sessions are secondary content — if their fetch fails (e.g. a missing
    /// Firestore index) the profile and Follow button must still work.
    var sessionsUnavailable = false

    private let uid: String
    private let userRepository: any UserRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    var onFollowChanged: ((Bool) -> Void)?

    init(uid: String, userRepository: any UserRepositoryProtocol, sessionRepository: any SessionRepositoryProtocol, onFollowChanged: ((Bool) -> Void)? = nil) {
        self.uid = uid
        self.userRepository = userRepository
        self.sessionRepository = sessionRepository
        self.onFollowChanged = onFollowChanged
    }

    func load() async {
        isLoading = true
        async let userTask = userRepository.fetchUser(uid: uid)
        async let followingTask = userRepository.isFollowing(targetUID: uid)

        do {
            let (u, f) = try await (userTask, followingTask)
            user = u
            isFollowing = f
        } catch {
            self.error = error
            isLoading = false
            return
        }

        await loadSessions()
        isLoading = false
    }

    // MARK: - Identity (derived from loaded sessions)

    /// Sends and attempts per grade across every loaded session, hardest
    /// first. Empty until sessions arrive or when the climber has none.
    var pyramidBars: [ClimberPyramidView.Bar] {
        var sends: [Int: Int] = [:]
        var attempts: [Int: Int] = [:]
        for session in sessions {
            for climb in session.climbs where climb.gradeNumeric >= 0 {
                if climb.climbOutcome.isCompleted {
                    sends[climb.gradeNumeric, default: 0] += 1
                } else {
                    attempts[climb.gradeNumeric, default: 0] += 1
                }
            }
        }
        return Set(sends.keys).union(attempts.keys)
            .sorted(by: >)
            .map { ClimberPyramidView.Bar(numeric: $0, sends: sends[$0] ?? 0, attempts: attempts[$0] ?? 0) }
    }

    /// The gym that shows up most in their sessions, display-cased.
    var homeGym: String? {
        var counts: [String: (count: Int, display: String)] = [:]
        for session in sessions {
            let display = session.gymName.trimmedGymName
            let key = display.lowercased()
            guard !key.isEmpty else { continue }
            counts[key, default: (0, display)].count += 1
        }
        return counts.values.max { $0.count < $1.count }?.display
    }

    var lastSessionDate: Date? {
        sessions.map(\.date).max()
    }

    /// Flashes as a share of completed climbs, as a whole percent. Nil until
    /// there are enough sends for the number to mean something.
    var flashRatePercent: Int? {
        var completed = 0
        var flashes = 0
        for session in sessions {
            for climb in session.climbs where climb.climbOutcome.isCompleted {
                completed += 1
                if climb.climbOutcome == .flash { flashes += 1 }
            }
        }
        guard completed >= 5 else { return nil }
        return Int((Double(flashes) / Double(completed) * 100).rounded())
    }

    var loadedClimbCount: Int {
        sessions.reduce(0) { $0 + $1.climbs.count }
    }

    func loadSessions() async {
        do {
            sessions = try await sessionRepository.fetchSessions(for: uid)
            sessionsUnavailable = false
        } catch {
            sessionsUnavailable = true
        }
    }

    func toggleFollow() async {
        guard user != nil else { return }
        do {
            if isFollowing {
                try await userRepository.unfollow(targetUID: uid)
                self.user?.followersCount = max(0, (self.user?.followersCount ?? 0) - 1)
            } else {
                try await userRepository.follow(targetUID: uid)
                self.user?.followersCount = (self.user?.followersCount ?? 0) + 1
            }
            isFollowing.toggle()
            onFollowChanged?(isFollowing)
        } catch {
            self.error = error
        }
    }
}
