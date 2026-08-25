import XCTest
import SwiftData
@testable import Gecko_Climbing

// MARK: - ClimbOutcome Tests

final class ClimbOutcomeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(ClimbOutcome.flash.rawValue, "flash")
        XCTAssertEqual(ClimbOutcome.sent.rawValue, "sent")
        XCTAssertEqual(ClimbOutcome.attempt.rawValue, "attempt")
    }

    func testIsCompleted() {
        XCTAssertTrue(ClimbOutcome.flash.isCompleted)
        XCTAssertTrue(ClimbOutcome.sent.isCompleted)
        XCTAssertFalse(ClimbOutcome.attempt.isCompleted)
    }

    func testFromStringLegacyFail() {
        XCTAssertEqual(ClimbOutcome.fromString("fail"), .attempt)
    }

    func testFromStringUnknown() {
        XCTAssertEqual(ClimbOutcome.fromString("garbage"), .attempt)
        XCTAssertEqual(ClimbOutcome.fromString(""), .attempt)
    }

    func testFromStringValid() {
        XCTAssertEqual(ClimbOutcome.fromString("flash"), .flash)
        XCTAssertEqual(ClimbOutcome.fromString("sent"), .sent)
        XCTAssertEqual(ClimbOutcome.fromString("project"), .attempt)
        XCTAssertEqual(ClimbOutcome.fromString("attempt"), .attempt)
    }

    func testDefaultAndMinAttempts() {
        XCTAssertEqual(ClimbOutcome.flash.defaultAttempts, 1)
        XCTAssertEqual(ClimbOutcome.flash.minAttempts, 1)
        XCTAssertEqual(ClimbOutcome.sent.defaultAttempts, 2)
        XCTAssertEqual(ClimbOutcome.sent.minAttempts, 2)
        XCTAssertEqual(ClimbOutcome.attempt.defaultAttempts, 1)
        XCTAssertEqual(ClimbOutcome.attempt.minAttempts, 1)
    }

    func testFromStringLegacyProject() {
        XCTAssertEqual(ClimbOutcome.fromString("project"), .attempt)
    }

    func testAllCases() {
        XCTAssertEqual(ClimbOutcome.allCases.count, 3)
    }
}

// MARK: - ClimbModel Tests

final class ClimbModelTests: XCTestCase {

    func testFlashAlwaysHas1Attempt() {
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .flash, attempts: 5)
        XCTAssertEqual(climb.attempts, 1)
        XCTAssertTrue(climb.isCompleted)
    }

    func testSentMinimum2Attempts() {
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 1)
        XCTAssertEqual(climb.attempts, 2)
    }

    func testSentAcceptsHigherAttempts() {
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 7)
        XCTAssertEqual(climb.attempts, 7)
    }

    func testProjectMinimum1Attempt() {
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .attempt, attempts: 0)
        XCTAssertEqual(climb.attempts, 1)
        XCTAssertFalse(climb.isCompleted)
    }

    func testAttemptMinimum1() {
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .attempt, attempts: 0)
        XCTAssertEqual(climb.attempts, 1)
    }

    func testClimbOutcomePropertyUpdatesFields() {
        let climb = ClimbModel(sessionId: "s1", grade: "V3", gradeNumeric: 3, outcome: .flash)
        XCTAssertEqual(climb.outcome, "flash")
        XCTAssertTrue(climb.isCompleted)

        climb.climbOutcome = .attempt
        XCTAssertEqual(climb.outcome, "attempt")
        XCTAssertFalse(climb.isCompleted)
    }

    func testDefaultOutcomeIsSent() {
        let climb = ClimbModel(sessionId: "s1", grade: "V3", gradeNumeric: 3)
        XCTAssertEqual(climb.climbOutcome, .sent)
        XCTAssertEqual(climb.attempts, 2) // default 1 bumped to min 2
    }
}

// MARK: - SessionModel Tests

final class SessionModelTests: XCTestCase {

    func testUpdateStatsCalculatesCorrectly() {
        let session = SessionModel(userId: "u1", gymName: "Test Gym")
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 3),
            ClimbModel(sessionId: session.sessionId, grade: "V7", gradeNumeric: 7, outcome: .attempt),
            ClimbModel(sessionId: session.sessionId, grade: "V4", gradeNumeric: 4, outcome: .attempt),
        ]
        session.updateStats()

        XCTAssertEqual(session.totalClimbs, 4)
        XCTAssertEqual(session.completedClimbs, 2) // flash + sent
        XCTAssertEqual(session.highestGrade, "V5") // highest completed
        XCTAssertEqual(session.highestGradeNumeric, 5)
    }

    func testUpdateStatsNoCompletedClimbs() {
        let session = SessionModel(userId: "u1", gymName: "Test Gym")
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V7", gradeNumeric: 7, outcome: .attempt),
            ClimbModel(sessionId: session.sessionId, grade: "V4", gradeNumeric: 4, outcome: .attempt),
        ]
        session.updateStats()

        XCTAssertEqual(session.totalClimbs, 2)
        XCTAssertEqual(session.completedClimbs, 0)
        XCTAssertEqual(session.highestGrade, "")
        XCTAssertEqual(session.highestGradeNumeric, -1)
    }

    func testUpdateStatsEmptyClimbs() {
        let session = SessionModel(userId: "u1", gymName: "Test Gym")
        session.updateStats()

        XCTAssertEqual(session.totalClimbs, 0)
        XCTAssertEqual(session.completedClimbs, 0)
        XCTAssertEqual(session.highestGrade, "")
        XCTAssertEqual(session.highestGradeNumeric, -1)
    }

    func testOutcomeCountProperties() {
        let session = SessionModel(userId: "u1", gymName: "Test Gym")
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 3),
            ClimbModel(sessionId: session.sessionId, grade: "V7", gradeNumeric: 7, outcome: .attempt),
            ClimbModel(sessionId: session.sessionId, grade: "V4", gradeNumeric: 4, outcome: .attempt),
            ClimbModel(sessionId: session.sessionId, grade: "V6", gradeNumeric: 6, outcome: .attempt),
        ]

        XCTAssertEqual(session.flashCount, 2)
        XCTAssertEqual(session.sentCount, 1)
        XCTAssertEqual(session.attemptCount, 3)
    }

    func testInitialState() {
        let session = SessionModel(userId: "u1", gymName: "Test Gym")
        XCTAssertTrue(session.climbs.isEmpty)
        XCTAssertFalse(session.isSyncedToFirestore)
        XCTAssertFalse(session.isLiveSession)
    }
}

// MARK: - VGrade Tests

final class VGradeTests: XCTestCase {

    func testNumericForValidGrades() {
        XCTAssertEqual(VGrade.numeric(for: "V0"), 0)
        XCTAssertEqual(VGrade.numeric(for: "V5"), 5)
        XCTAssertEqual(VGrade.numeric(for: "V17"), 17)
    }

    func testNumericCaseInsensitive() {
        XCTAssertEqual(VGrade.numeric(for: "v5"), 5)
        XCTAssertEqual(VGrade.numeric(for: "v10"), 10)
    }

    func testNumericInvalid() {
        XCTAssertEqual(VGrade.numeric(for: "abc"), -1)
        XCTAssertEqual(VGrade.numeric(for: ""), -1)
        XCTAssertEqual(VGrade.numeric(for: "V"), -1)
    }

    func testLabelValid() {
        XCTAssertEqual(VGrade.label(for: 0), "V0")
        XCTAssertEqual(VGrade.label(for: 5), "V5")
        XCTAssertEqual(VGrade.label(for: 17), "V17")
    }

    func testLabelOutOfRange() {
        XCTAssertEqual(VGrade.label(for: -1), "?")
        XCTAssertEqual(VGrade.label(for: 18), "?")
    }

    func testAllGrades() {
        XCTAssertEqual(VGrade.all.count, 18)
        XCTAssertEqual(VGrade.all.first, "V0")
        XCTAssertEqual(VGrade.all.last, "V17")
    }

    func testStandardGrades() {
        XCTAssertEqual(VGrade.standard.count, 11)
        XCTAssertEqual(VGrade.standard.first, "V0")
        XCTAssertEqual(VGrade.standard.last, "V10")
    }
}

// MARK: - DTO Roundtrip Tests

final class DTORoundtripTests: XCTestCase {

    func testClimbRoundtrip() {
        let original = ClimbModel(
            climbId: "climb-1",
            sessionId: "session-1",
            grade: "V5",
            gradeNumeric: 5,
            outcome: .flash,
            attempts: 1,
            notes: "Clean send",
            photoURL: "https://example.com/photo.jpg",
            loggedAt: Date(timeIntervalSince1970: 1700000000)
        )

        let dto = original.toDTO()
        let restored = dto.toModel()

        XCTAssertEqual(restored.climbId, original.climbId)
        XCTAssertEqual(restored.sessionId, original.sessionId)
        XCTAssertEqual(restored.grade, original.grade)
        XCTAssertEqual(restored.gradeNumeric, original.gradeNumeric)
        XCTAssertEqual(restored.climbOutcome, original.climbOutcome)
        XCTAssertEqual(restored.attempts, original.attempts)
        XCTAssertEqual(restored.notes, original.notes)
        XCTAssertEqual(restored.photoURL, original.photoURL)
        XCTAssertEqual(restored.loggedAt, original.loggedAt)
    }

    func testClimbDTODictionaryIncludesAllFields() {
        let dto = ClimbDTO(
            id: "c1",
            sessionId: "s1",
            grade: "V5",
            gradeNumeric: 5,
            isCompleted: true,
            attempts: 1,
            outcome: "flash",
            notes: "Test",
            photoURL: "https://example.com",
            loggedAt: Date()
        )
        let dict = dto.asDictionary()

        XCTAssertEqual(dict["sessionId"] as? String, "s1")
        XCTAssertEqual(dict["grade"] as? String, "V5")
        XCTAssertEqual(dict["gradeNumeric"] as? Int, 5)
        XCTAssertEqual(dict["isCompleted"] as? Bool, true)
        XCTAssertEqual(dict["attempts"] as? Int, 1)
        XCTAssertEqual(dict["outcome"] as? String, "flash")
        XCTAssertEqual(dict["notes"] as? String, "Test")
        XCTAssertEqual(dict["photoURL"] as? String, "https://example.com")
    }

    func testClimbDTODictionaryOmitsNilPhoto() {
        let dto = ClimbDTO(
            id: "c1", sessionId: "s1", grade: "V5", gradeNumeric: 5,
            isCompleted: true, attempts: 1, outcome: "flash", notes: "",
            photoURL: nil, loggedAt: Date()
        )
        let dict = dto.asDictionary()
        XCTAssertNil(dict["photoURL"])
    }

    func testSessionRoundtrip() {
        let startDate = Date(timeIntervalSince1970: 1699990000)
        let original = SessionModel(
            sessionId: "sess-1",
            userId: "user-1",
            gymName: "The Wall",
            date: Date(timeIntervalSince1970: 1700000000),
            durationMinutes: 90,
            notes: "Great session",
            photoURLs: ["url1", "url2"],
            totalClimbs: 5,
            completedClimbs: 3,
            highestGrade: "V6",
            highestGradeNumeric: 6,
            isLiveSession: true,
            startedAt: startDate
        )

        let dto = original.toDTO()
        let restored = dto.toModel()

        XCTAssertEqual(restored.sessionId, original.sessionId)
        XCTAssertEqual(restored.userId, original.userId)
        XCTAssertEqual(restored.gymName, original.gymName)
        XCTAssertEqual(restored.date, original.date)
        XCTAssertEqual(restored.durationMinutes, original.durationMinutes)
        XCTAssertEqual(restored.notes, original.notes)
        XCTAssertEqual(restored.photoURLs, original.photoURLs)
        XCTAssertEqual(restored.totalClimbs, original.totalClimbs)
        XCTAssertEqual(restored.completedClimbs, original.completedClimbs)
        XCTAssertEqual(restored.highestGrade, original.highestGrade)
        XCTAssertEqual(restored.highestGradeNumeric, original.highestGradeNumeric)
        XCTAssertTrue(restored.isSyncedToFirestore) // DTO sets this
        XCTAssertEqual(restored.isLiveSession, original.isLiveSession)
        XCTAssertEqual(restored.startedAt, original.startedAt)
    }

    func testSessionDTODictionaryAllFields() {
        let start = Date()
        let dto = SessionDTO(
            id: "s1", userId: "u1", gymName: "Gym", date: Date(),
            durationMinutes: 60, notes: "Notes", photoURLs: ["url"],
            totalClimbs: 3, completedClimbs: 2, highestGrade: "V5",
            highestGradeNumeric: 5, isLiveSession: true, startedAt: start,
            createdAt: Date()
        )
        let dict = dto.asDictionary()

        XCTAssertEqual(dict["userId"] as? String, "u1")
        XCTAssertEqual(dict["gymName"] as? String, "Gym")
        XCTAssertEqual(dict["durationMinutes"] as? Int, 60)
        XCTAssertEqual(dict["notes"] as? String, "Notes")
        XCTAssertEqual(dict["totalClimbs"] as? Int, 3)
        XCTAssertEqual(dict["completedClimbs"] as? Int, 2)
        XCTAssertEqual(dict["highestGrade"] as? String, "V5")
        XCTAssertEqual(dict["highestGradeNumeric"] as? Int, 5)
        XCTAssertEqual((dict["photoURLs"] as? [String])?.count, 1)
        XCTAssertEqual(dict["isLiveSession"] as? Bool, true)
        XCTAssertNotNil(dict["startedAt"])
    }

    func testUserRoundtrip() {
        let original = UserModel(
            uid: "uid-1",
            displayName: "Alex Stone",
            username: "alex_stone",
            bio: "Climbing is life",
            profileImageURL: "https://example.com/photo.jpg",
            followersCount: 10,
            followingCount: 5,
            totalSessions: 20,
            totalClimbs: 100,
            highestGrade: "V8",
            highestGradeNumeric: 8,
            isPublic: true
        )

        let dto = original.toDTO()
        let restored = dto.toModel()

        XCTAssertEqual(restored.uid, original.uid)
        XCTAssertEqual(restored.displayName, original.displayName)
        XCTAssertEqual(restored.username, original.username)
        XCTAssertEqual(restored.bio, original.bio)
        XCTAssertEqual(restored.profileImageURL, original.profileImageURL)
        XCTAssertEqual(restored.followersCount, original.followersCount)
        XCTAssertEqual(restored.followingCount, original.followingCount)
        XCTAssertEqual(restored.totalSessions, original.totalSessions)
        XCTAssertEqual(restored.totalClimbs, original.totalClimbs)
        XCTAssertEqual(restored.highestGrade, original.highestGrade)
        XCTAssertEqual(restored.highestGradeNumeric, original.highestGradeNumeric)
        XCTAssertEqual(restored.isPublic, original.isPublic)
    }

    func testPostRoundtrip() {
        let original = PostModel(
            postId: "post-1",
            userId: "u1",
            userDisplayName: "Alex",
            userProfileImageURL: "https://example.com/photo.jpg",
            sessionId: "s1",
            gymName: "Boulder World",
            type: "session",
            caption: "Great sesh!",
            imageURL: "https://example.com/img.jpg",
            likesCount: 5,
            commentsCount: 2,
            createdAt: Date(timeIntervalSince1970: 1700000000),
            topGrade: "V7",
            topGradeNumeric: 7,
            totalClimbs: 10,
            gradeCounts: ["V5": 3, "V6": 4, "V7": 3],
            visibility: "public"
        )

        let dto = original.toDTO()
        let restored = dto.toModel()

        XCTAssertEqual(restored.postId, original.postId)
        XCTAssertEqual(restored.userId, original.userId)
        XCTAssertEqual(restored.userDisplayName, original.userDisplayName)
        XCTAssertEqual(restored.sessionId, original.sessionId)
        XCTAssertEqual(restored.gymName, original.gymName)
        XCTAssertEqual(restored.caption, original.caption)
        XCTAssertEqual(restored.imageURL, original.imageURL)
        XCTAssertEqual(restored.likesCount, original.likesCount)
        XCTAssertEqual(restored.commentsCount, original.commentsCount)
        XCTAssertEqual(restored.topGrade, original.topGrade)
        XCTAssertEqual(restored.topGradeNumeric, original.topGradeNumeric)
        XCTAssertEqual(restored.totalClimbs, original.totalClimbs)
        XCTAssertEqual(restored.gradeCounts, original.gradeCounts)
        XCTAssertEqual(restored.visibility, original.visibility)
    }

    func testPostDTODictionaryOmitsNilImage() {
        let dto = PostDTO(
            id: "p1", userId: "u1", userDisplayName: "Alex",
            userProfileImageURL: "", sessionId: "s1", gymName: "Gym",
            type: "session", caption: "Test", imageURL: nil, imageURLs: [],
            likesCount: 0, commentsCount: 0, createdAt: Date(),
            topGrade: "V5", topGradeNumeric: 5, totalClimbs: 1,
            gradeCounts: ["V5": 1], gradeSequence: [], outcomeSequence: [], sessionDurationMinutes: nil, visibility: "followers"
        )
        let dict = dto.asDictionary()
        XCTAssertNil(dict["imageURL"])
    }
}

// MARK: - Mock Auth Repository Tests

final class MockAuthRepositoryTests: XCTestCase {

    func testSignInValidCredentials() async throws {
        let auth = MockAuthRepository()
        try await auth.signIn(email: "user1@test.com", password: "password123")

        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUserId, "user1")
        XCTAssertEqual(auth.currentUserDisplayName, "Alex Stone")
    }

    func testSignInInvalidCredentials() async {
        let auth = MockAuthRepository()
        do {
            try await auth.signIn(email: "wrong@test.com", password: "wrong")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is AuthError)
        }
    }

    func testSignUpDuplicateEmail() async {
        let auth = MockAuthRepository()
        do {
            try await auth.signUp(email: "user1@test.com", password: "pass", username: "test", displayName: "Test")
            XCTFail("Should have thrown")
        } catch let error as AuthError {
            guard case .emailAlreadyInUse = error else {
                return XCTFail("Wrong AuthError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testSignUpNewEmail() async throws {
        let auth = MockAuthRepository()
        try await auth.signUp(email: "new@example.com", password: "pass", username: "newuser", displayName: "New User")

        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUserDisplayName, "New User")
    }

    func testSignOut() async throws {
        let auth = MockAuthRepository()
        try await auth.signIn(email: "user1@test.com", password: "password123")
        XCTAssertTrue(auth.isAuthenticated)

        try auth.signOut()
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertEqual(auth.currentUserId, "")
        XCTAssertEqual(auth.currentUserDisplayName, "")
    }

    func testAuthStateListener() async throws {
        let auth = MockAuthRepository()
        var stateChanges: [Bool] = []

        auth.addAuthStateListener { isAuth in
            stateChanges.append(isAuth)
        }

        // Listener fires immediately with current state
        XCTAssertEqual(stateChanges, [false])

        try await auth.signIn(email: "user1@test.com", password: "password123")
        XCTAssertEqual(stateChanges, [false, true])

        try auth.signOut()
        XCTAssertEqual(stateChanges, [false, true, false])
    }
}

// MARK: - Mock Session Repository Tests

final class MockSessionRepositoryTests: XCTestCase {

    func testSeedSessionsGenerated() async throws {
        let repo = MockSessionRepository(currentUserId: "testUser")
        let sessions = try await repo.fetchSessions(for: "testUser")

        XCTAssertEqual(sessions.count, 5)
        // Sorted by date descending
        for i in 0..<(sessions.count - 1) {
            XCTAssertGreaterThanOrEqual(sessions[i].date, sessions[i + 1].date)
        }
    }

    func testFetchSessionsWrongUser() async throws {
        let repo = MockSessionRepository(currentUserId: "testUser")
        let sessions = try await repo.fetchSessions(for: "differentUser")
        XCTAssertTrue(sessions.isEmpty)
    }

    func testSeedSessionsHaveClimbs() async throws {
        let repo = MockSessionRepository(currentUserId: "testUser")
        let sessions = try await repo.fetchSessions(for: "testUser")

        for session in sessions {
            XCTAssertFalse(session.climbs.isEmpty, "Session \(session.sessionId) should have climbs")
            XCTAssertGreaterThan(session.totalClimbs, 0)
        }
    }

    /// The in-app self-heal migration: existing sessions logged under gym-name
    /// variants (trailing space / casing) converge to one canonical spelling —
    /// the most recent session's trimmed form.
    func testNormalizeGymNamesMergesVariants() async throws {
        let repo = MockSessionRepository(currentUserId: "gymmig")
        let container = try ModelContainer(
            for: SessionModel.self, ClimbModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)

        // Same gym, three spellings; the newest is the clean "ZZ Test Gym".
        let variants: [(String, Date)] = [
            ("zz test gym",  Date(timeIntervalSince1970: 1_000)),
            ("ZZ Test Gym ", Date(timeIntervalSince1970: 2_000)),
            ("ZZ Test Gym",  Date(timeIntervalSince1970: 3_000)),
        ]
        for (name, date) in variants {
            try await repo.createSession(
                SessionModel(userId: "gymmig", gymName: name, date: date), context: ctx
            )
        }

        let ok = await repo.normalizeGymNames(for: "gymmig")
        XCTAssertTrue(ok)

        let names = try await repo.fetchSessions(for: "gymmig")
            .map(\.gymName)
            .filter { $0.lowercased().contains("zz test gym") }
        XCTAssertEqual(names.count, 3)
        XCTAssertEqual(Set(names), ["ZZ Test Gym"]) // all merged to the canonical spelling
    }
}

// MARK: - Gym Name Dedupe Tests

final class GymNameDedupeTests: XCTestCase {

    /// The reported bug: the same gym typed with a stray trailing space (common
    /// from iOS keyboard autocomplete) appeared twice in the suggestion list,
    /// because exact Set<String> de-duplication treated it as a distinct name.
    func testDedupeIgnoresSurroundingWhitespace() {
        let raw = ["Dogpatch Boulders", "Dogpatch Boulders ", " Dogpatch Boulders"]
        XCTAssertEqual(raw.dedupedGymNames(), ["Dogpatch Boulders"])
    }

    func testDedupeIgnoresCase() {
        XCTAssertEqual(["Movement", "movement", "MOVEMENT"].dedupedGymNames(), ["Movement"])
    }

    /// Preserves recency order, trims the surviving display value, drops blanks,
    /// and keeps genuinely distinct gyms.
    func testDedupePreservesOrderTrimsAndDropsBlanks() {
        let raw = ["Dogpatch Boulders ", "", "   ", "The Spot", "dogpatch boulders", "The Spot"]
        XCTAssertEqual(raw.dedupedGymNames(), ["Dogpatch Boulders", "The Spot"])
    }
}

// MARK: - Mock User Repository Tests

final class MockUserRepositoryTests: XCTestCase {

    func testFetchCurrentUserReturnsSeedUser() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        // The seed data maps first user to currentUserId
        // If currentUserId doesn't match any seed, it auto-creates
        let user = try await repo.fetchCurrentUser()
        XCTAssertEqual(user.uid, "user1")
    }

    func testFetchCurrentUserMatchesSeedData() async throws {
        // The seed data maps currentUserId to the first user "Alex Stone"
        let repo = MockUserRepository(currentUserId: "newUser")
        let user = try await repo.fetchCurrentUser()
        XCTAssertEqual(user.uid, "newUser")
        XCTAssertFalse(user.displayName.isEmpty)
    }

    func testFollowAndUnfollow() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        let target = MockSeed.rileyUserId

        let before = try await repo.isFollowing(targetUID: target)
        XCTAssertFalse(before)

        try await repo.follow(targetUID: target)
        let afterFollow = try await repo.isFollowing(targetUID: target)
        XCTAssertTrue(afterFollow)

        let following = try await repo.fetchFollowing(uid: "user1")
        XCTAssertTrue(following.contains { $0.uid == target })

        try await repo.unfollow(targetUID: target)
        let afterUnfollow = try await repo.isFollowing(targetUID: target)
        XCTAssertFalse(afterUnfollow)
    }

    func testSearchExcludesSelf() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        // Search for a name that might include current user
        let results = try await repo.searchUsers(query: "a") // broad query
        XCTAssertTrue(results.allSatisfy { $0.uid != "user1" })
    }

    func testSearchReturnsMatching() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        let results = try await repo.searchUsers(query: "Riley")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.displayName, MockSeed.rileyDisplayName)
    }

    func testSearchEmptyQuery() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        let results = try await repo.searchUsers(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testFollowIncrementsCount() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        let beforeUser = try await repo.fetchUser(uid: MockSeed.rileyUserId)
        let beforeCount = beforeUser.followersCount

        try await repo.follow(targetUID: MockSeed.rileyUserId)
        let afterUser = try await repo.fetchUser(uid: MockSeed.rileyUserId)

        XCTAssertEqual(afterUser.followersCount, beforeCount + 1)
    }

    func testUnfollowDoesNotGoNegative() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        // Unfollow someone we're not following — count should not go below 0
        let beforeUser = try await repo.fetchUser(uid: MockSeed.rileyUserId)
        _ = beforeUser.followersCount

        try await repo.unfollow(targetUID: MockSeed.rileyUserId)
        let afterUser = try await repo.fetchUser(uid: MockSeed.rileyUserId)
        XCTAssertGreaterThanOrEqual(afterUser.followersCount, 0)
    }
}

// MARK: - Mock Post Repository Tests

final class MockPostRepositoryTests: XCTestCase {

    func testSeedFeedHasPosts() async throws {
        let repo = MockPostRepository()
        let posts = try await repo.fetchFeed(for: "user1")
        XCTAssertFalse(posts.isEmpty)
        // Sorted by date descending
        for i in 0..<(posts.count - 1) {
            XCTAssertGreaterThanOrEqual(posts[i].createdAt, posts[i + 1].createdAt)
        }
    }

    func testLikeAndUnlike() async throws {
        let repo = MockPostRepository()
        let posts = try await repo.fetchFeed(for: "user1")
        let firstPost = posts[0]
        let originalLikes = firstPost.likesCount

        try await repo.likePost(firstPost.postId, userId: "user1")
        let afterLike = try await repo.fetchFeed(for: "user1")
        let likedPost = afterLike.first { $0.postId == firstPost.postId }!
        XCTAssertEqual(likedPost.likesCount, originalLikes + 1)
        XCTAssertTrue(likedPost.isLikedByCurrentUser)

        try await repo.unlikePost(firstPost.postId, userId: "user1")
        let afterUnlike = try await repo.fetchFeed(for: "user1")
        let unlikedPost = afterUnlike.first { $0.postId == firstPost.postId }!
        XCTAssertEqual(unlikedPost.likesCount, originalLikes)
        XCTAssertFalse(unlikedPost.isLikedByCurrentUser)
    }

    func testDeletePost() async throws {
        let repo = MockPostRepository()
        let posts = try await repo.fetchFeed(for: "user1")
        let firstPost = posts[0]

        try await repo.deletePost(firstPost.postId)
        let afterDelete = try await repo.fetchFeed(for: "user1")
        XCTAssertEqual(afterDelete.count, posts.count - 1)
        XCTAssertFalse(afterDelete.contains { $0.postId == firstPost.postId })
    }

    func testCreatePost() async throws {
        let repo = MockPostRepository()
        let post = PostModel(
            userId: "user1", userDisplayName: "Test User",
            sessionId: "s1", gymName: "Test Gym", caption: "Test post"
        )

        try await repo.createPost(post)
        let posts = try await repo.fetchFeed(for: "user1")
        XCTAssertTrue(posts.contains { $0.postId == post.postId })
    }

    func testFetchPostsFiltersByUser() async throws {
        let repo = MockPostRepository()
        let posts = try await repo.fetchPosts(for: "friend_1")
        XCTAssertTrue(posts.allSatisfy { $0.userId == "friend_1" })
    }
}

// MARK: - Mock Climb Repository Tests

final class MockClimbRepositoryTests: XCTestCase {

    func testAddAndFetch() async throws {
        let repo = MockClimbRepository()
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .flash)

        try await repo.addClimb(climb, to: "s1")
        let fetched = try await repo.fetchClimbs(for: "s1")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].climbId, climb.climbId)
    }

    func testDeleteClimb() async throws {
        let repo = MockClimbRepository()
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .flash)

        try await repo.addClimb(climb, to: "s1")
        try await repo.deleteClimb(climb.climbId, from: "s1")
        let fetched = try await repo.fetchClimbs(for: "s1")
        XCTAssertTrue(fetched.isEmpty)
    }

    func testFetchFiltersBySession() async throws {
        let repo = MockClimbRepository()
        let climb1 = ClimbModel(sessionId: "s1", grade: "V3", gradeNumeric: 3, outcome: .flash)
        let climb2 = ClimbModel(sessionId: "s2", grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 3)

        try await repo.addClimb(climb1, to: "s1")
        try await repo.addClimb(climb2, to: "s2")

        let s1Climbs = try await repo.fetchClimbs(for: "s1")
        XCTAssertEqual(s1Climbs.count, 1)
        XCTAssertEqual(s1Climbs[0].sessionId, "s1")

        let s2Climbs = try await repo.fetchClimbs(for: "s2")
        XCTAssertEqual(s2Climbs.count, 1)
        XCTAssertEqual(s2Climbs[0].sessionId, "s2")
    }
}

// MARK: - NewSessionViewModel Tests

@MainActor
final class NewSessionViewModelTests: XCTestCase {

    func testAddClimbInsertsAtBeginning() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")

        vm.addClimb(grade: "V3", outcome: .flash, attempts: 1)
        vm.addClimb(grade: "V5", outcome: .sent, attempts: 3)

        XCTAssertEqual(vm.climbs.count, 2)
        XCTAssertEqual(vm.climbs[0].grade, "V5") // most recent first
        XCTAssertEqual(vm.climbs[1].grade, "V3")
    }

    func testRemoveClimb() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")

        vm.addClimb(grade: "V3", outcome: .flash, attempts: 1)
        vm.addClimb(grade: "V5", outcome: .sent, attempts: 3)
        vm.removeClimb(at: IndexSet(integer: 0))

        XCTAssertEqual(vm.climbs.count, 1)
        XCTAssertEqual(vm.climbs[0].grade, "V3")
    }

    func testClimbCategories() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")

        vm.addClimb(grade: "V3", outcome: .flash, attempts: 1)
        vm.addClimb(grade: "V5", outcome: .sent, attempts: 3)
        vm.addClimb(grade: "V7", outcome: .attempt, attempts: 5)
        vm.addClimb(grade: "V2", outcome: .attempt, attempts: 2)

        XCTAssertEqual(vm.flashes.count, 1)
        XCTAssertEqual(vm.sends.count, 1)
        XCTAssertEqual(vm.attempts.count, 2)
    }

    func testTotalDuration() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")
        vm.durationHours = 2
        vm.durationMinutes = 15
        XCTAssertEqual(vm.totalDurationMinutes, 135)
    }

    func testClimbSummaryTextNoClimbs() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")
        XCTAssertEqual(vm.climbSummaryText, "No climbs")
    }

    func testClimbSummaryTextMixed() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")

        vm.addClimb(grade: "V3", outcome: .flash, attempts: 1)
        vm.addClimb(grade: "V5", outcome: .sent, attempts: 3)

        XCTAssertTrue(vm.climbSummaryText.contains("flash"))
        XCTAssertTrue(vm.climbSummaryText.contains("send"))
    }

    func testElapsedTimeFormat() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")
        XCTAssertTrue(vm.elapsedTimeFormatted.contains(":"))
    }

    func testAddClimbSetsSessionIdToPending() {
        let repo = MockSessionRepository(currentUserId: "u1")
        let vm = NewSessionViewModel(sessionRepository: repo, userId: "u1")
        vm.addClimb(grade: "V5", outcome: .flash, attempts: 1)
        XCTAssertEqual(vm.climbs[0].sessionId, "pending")
    }
}

// MARK: - HomeViewModel Tests

@MainActor
final class HomeViewModelTests: XCTestCase {

    func testLoadFeedPopulatesPosts() async {
        let repo = MockPostRepository()
        let vm = HomeViewModel(
            postRepository: repo,
            userRepository: MockUserRepository(currentUserId: "user1"),
            sessionRepository: MockSessionRepository(currentUserId: "user1"),
            feedbackRepository: MockFeedbackRepository(),
            userId: "user1"
        )

        await vm.loadFeed()

        XCTAssertFalse(vm.followingPosts.isEmpty)
        XCTAssertFalse(vm.isLoadingFollowing)
        XCTAssertNil(vm.error)
    }

    func testToggleLikeFlipsState() async {
        let repo = MockPostRepository()
        let vm = HomeViewModel(
            postRepository: repo,
            userRepository: MockUserRepository(currentUserId: "user1"),
            sessionRepository: MockSessionRepository(currentUserId: "user1"),
            feedbackRepository: MockFeedbackRepository(),
            userId: "user1"
        )

        await vm.loadFeed()
        guard let post = vm.followingPosts.first else {
            XCTFail("No posts in feed")
            return
        }

        let wasLiked = post.isLikedByCurrentUser

        await vm.toggleLike(post)

        let updated = vm.followingPosts.first { $0.postId == post.postId }!
        XCTAssertEqual(updated.isLikedByCurrentUser, !wasLiked)
    }

    func testToggleLikeNonExistentPost() async {
        let repo = MockPostRepository()
        let vm = HomeViewModel(
            postRepository: repo,
            userRepository: MockUserRepository(currentUserId: "user1"),
            sessionRepository: MockSessionRepository(currentUserId: "user1"),
            feedbackRepository: MockFeedbackRepository(),
            userId: "user1"
        )
        await vm.loadFeed()

        let fakePost = PostModel(postId: "nonexistent", userId: "u1", sessionId: "s1")
        await vm.toggleLike(fakePost)
        // Should not crash, just no-op
    }
}

// MARK: - StatsViewModel Tests

@MainActor
final class StatsViewModelTests: XCTestCase {

    func testComputedStats() {
        let vm = StatsViewModel(
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            userId: "u1"
        )

        let session = SessionModel(userId: "u1", gymName: "Test")
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 3),
            ClimbModel(sessionId: session.sessionId, grade: "V7", gradeNumeric: 7, outcome: .attempt),
        ]
        session.updateStats()
        vm.sessions = [session]

        XCTAssertEqual(vm.totalSessions, 1)
        XCTAssertEqual(vm.totalClimbs, 3)
        XCTAssertEqual(vm.totalSends, 2) // flash + sent
        XCTAssertEqual(vm.highestGrade, "V5")
        XCTAssertEqual(vm.highestGradeNumeric, 5)
    }

    func testGradePyramid() {
        let vm = StatsViewModel(
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            userId: "u1"
        )

        let session = SessionModel(userId: "u1", gymName: "Test")
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .sent, attempts: 2),
            ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V7", gradeNumeric: 7, outcome: .attempt),
        ]
        session.updateStats()
        vm.sessions = [session]

        let pyramid = vm.gradePyramidData
        XCTAssertEqual(pyramid.count, 2) // V3 and V5 (V7 is not completed)
        XCTAssertEqual(pyramid[0].grade, "V3")
        XCTAssertEqual(pyramid[0].count, 2)
        XCTAssertEqual(pyramid[1].grade, "V5")
        XCTAssertEqual(pyramid[1].count, 1)
    }

    func testEmptyStats() {
        let vm = StatsViewModel(
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            userId: "u1"
        )
        vm.sessions = []

        XCTAssertEqual(vm.totalSessions, 0)
        XCTAssertEqual(vm.totalClimbs, 0)
        XCTAssertEqual(vm.totalSends, 0)
        XCTAssertEqual(vm.highestGrade, "—")
        XCTAssertTrue(vm.gradePyramidData.isEmpty)
        XCTAssertTrue(vm.progressData.isEmpty)
    }

    func testProgressDataSortedByDate() {
        let vm = StatsViewModel(
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            userId: "u1"
        )

        let s1 = SessionModel(userId: "u1", gymName: "Gym", date: Date().addingTimeInterval(-86400 * 3))
        s1.climbs = [ClimbModel(sessionId: s1.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash)]
        s1.updateStats()

        let s2 = SessionModel(userId: "u1", gymName: "Gym", date: Date().addingTimeInterval(-86400))
        s2.climbs = [ClimbModel(sessionId: s2.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 2)]
        s2.updateStats()

        vm.sessions = [s1, s2]

        let progress = vm.progressData
        XCTAssertEqual(progress.count, 2)
        XCTAssertLessThan(progress[0].date, progress[1].date)
        XCTAssertEqual(progress[0].highestGradeNumeric, 3)
        XCTAssertEqual(progress[1].highestGradeNumeric, 5)
    }

    func testLoadStats() async {
        let vm = StatsViewModel(
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            userId: "u1"
        )

        await vm.loadStats()
        XCTAssertFalse(vm.sessions.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    /// The same gym typed inconsistently (trailing space, casing) must count as
    /// one gym in the Top Gyms breakdown — the historical-stats side of the
    /// duplicate-gym bug.
    func testTopGymsMergesGymNameVariants() {
        let vm = StatsViewModel(
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            userId: "u1"
        )
        vm.sessions = [
            SessionModel(userId: "u1", gymName: "Dogpatch Boulders"),
            SessionModel(userId: "u1", gymName: "Dogpatch Boulders "),
            SessionModel(userId: "u1", gymName: "dogpatch boulders"),
            SessionModel(userId: "u1", gymName: "The Spot"),
        ]

        let gyms = vm.topGyms
        XCTAssertEqual(gyms.count, 2)
        let dogpatch = gyms.first { $0.name.lowercased().contains("dogpatch") }
        XCTAssertEqual(dogpatch?.sessionCount, 3)
        XCTAssertEqual(dogpatch?.name.trimmedGymName, dogpatch?.name) // display is trimmed
    }
}

// MARK: - SessionDetailViewModel Tests

@MainActor
final class SessionDetailViewModelTests: XCTestCase {

    func testSortedClimbsChronological() {
        let session = SessionModel(userId: "u1", gymName: "Test")
        let older = ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash, loggedAt: Date().addingTimeInterval(-3600))
        let newer = ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 2, loggedAt: Date())
        session.climbs = [newer, older]

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"), postRepository: MockPostRepository())

        // Chronological: first logged climb (V3) comes first, latest (V5) last.
        XCTAssertEqual(vm.sortedClimbs[0].grade, "V3")
        XCTAssertEqual(vm.sortedClimbs[1].grade, "V5")
    }

    func testOutcomeFilters() {
        let session = SessionModel(userId: "u1", gymName: "Test")
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash),
            ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 2),
            ClimbModel(sessionId: session.sessionId, grade: "V7", gradeNumeric: 7, outcome: .attempt),
            ClimbModel(sessionId: session.sessionId, grade: "V2", gradeNumeric: 2, outcome: .attempt),
        ]

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"), postRepository: MockPostRepository())

        XCTAssertEqual(vm.flashes.count, 1)
        XCTAssertEqual(vm.sends.count, 1)
        XCTAssertEqual(vm.fails.count, 2) // both attempts
    }

    func testAddClimb() async {
        let session = SessionModel(userId: "u1", gymName: "Test")
        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"), postRepository: MockPostRepository())

        await vm.addClimb(grade: "V5", outcome: .flash, attempts: 1)

        XCTAssertEqual(vm.session.climbs.count, 1)
        XCTAssertEqual(vm.session.totalClimbs, 1)
        XCTAssertEqual(vm.session.highestGrade, "V5")
    }

    func testDeleteClimb() async {
        let session = SessionModel(userId: "u1", gymName: "Test")
        let climb = ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .flash)
        session.climbs = [climb]
        session.updateStats()

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"), postRepository: MockPostRepository())
        await vm.deleteClimb(climb)

        XCTAssertTrue(vm.session.climbs.isEmpty)
        XCTAssertEqual(vm.session.totalClimbs, 0)
    }

    /// Editing a session must cascade its denormalized snapshot onto the linked
    /// feed post — the bug this fixes was the post going stale after an edit.
    func testEditSyncsLinkedFeedPost() async throws {
        let session = SessionModel(userId: "u1", gymName: "Movement")
        let starter = ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash)
        session.climbs = [starter]
        session.updateStats()

        // A shared post pointing at this session, seeded into the post repo.
        let postRepo = MockPostRepository()
        let post = PostModel(userId: "u1", sessionId: session.sessionId, gymName: "Movement",
                             topGrade: "V3", topGradeNumeric: 3, totalClimbs: 1, gradeCounts: ["V3": 1])
        try await postRepo.createPost(post)

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"), postRepository: postRepo)

        // Add a harder climb — the post's headline grade and counts should follow.
        await vm.addClimb(grade: "V6", outcome: .sent, attempts: 3)

        let synced = try await postRepo.fetchPosts(for: "u1").first { $0.sessionId == session.sessionId }
        let updated = try XCTUnwrap(synced)
        XCTAssertEqual(updated.topGrade, "V6")
        XCTAssertEqual(updated.topGradeNumeric, 6)
        XCTAssertEqual(updated.totalClimbs, 2)
        XCTAssertEqual(updated.gradeCounts["V6"], 1)
        XCTAssertEqual(updated.gradeSequence, ["V3", "V6"])
        XCTAssertEqual(updated.outcomeSequence, ["flash", "sent"])
    }

    /// Editing a session that was never shared must not error — the post sync
    /// is a no-op when no post references the session.
    func testEditWithNoLinkedPostIsNoOp() async {
        let session = SessionModel(userId: "u1", gymName: "Test")
        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"), postRepository: MockPostRepository())

        await vm.addClimb(grade: "V4", outcome: .flash, attempts: 1)

        XCTAssertNil(vm.error)
        XCTAssertEqual(vm.session.climbs.count, 1)
    }
}

// MARK: - SocialViewModel Tests

@MainActor
final class SocialViewModelTests: XCTestCase {

    func testFollowState() async {
        let repo = MockUserRepository(currentUserId: "user1")
        let vm = SocialViewModel(userRepository: repo, userId: "user1")

        XCTAssertFalse(vm.isFollowing("friend_1"))

        await vm.follow(user: UserModel(uid: "friend_1", displayName: "Sam", username: "sam"))
        XCTAssertTrue(vm.isFollowing("friend_1"))

        await vm.unfollow(user: UserModel(uid: "friend_1", displayName: "Sam", username: "sam"))
        XCTAssertFalse(vm.isFollowing("friend_1"))
    }

    func testLoadFollowing() async {
        let repo = MockUserRepository(currentUserId: "user1")
        let vm = SocialViewModel(userRepository: repo, userId: "user1")

        // Follow a user that exists in the mock seed so loadFollowing() (which
        // resolves followed UIDs back to seeded UserModels) can return it.
        await vm.follow(user: UserModel(uid: MockSeed.rileyUserId, displayName: MockSeed.rileyDisplayName, username: "riley"))
        await vm.loadFollowing()

        XCTAssertFalse(vm.following.isEmpty)
    }

    func testFollowPreventsDuplicates() async {
        let repo = MockUserRepository(currentUserId: "user1")
        let vm = SocialViewModel(userRepository: repo, userId: "user1")

        let user = UserModel(uid: "friend_1", displayName: "Sam", username: "sam")
        await vm.follow(user: user)
        await vm.follow(user: user) // follow again

        // Should not have duplicate entries in following array
        let count = vm.following.filter { $0.uid == "friend_1" }.count
        XCTAssertEqual(count, 1)
    }
}

// MARK: - ProfileViewModel Tests

@MainActor
final class ProfileViewModelTests: XCTestCase {

    func testWeeklyStreakNoSessions() {
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(currentUserId: "u1"),
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            storageRepository: MockStorageRepository(),
            postRepository: MockPostRepository(),
            userId: "u1"
        )
        vm.allSessions = []
        XCTAssertEqual(vm.weeklyStreak, 0)
    }

    func testWeeklyStreakCurrentWeek() {
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(currentUserId: "u1"),
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            storageRepository: MockStorageRepository(),
            postRepository: MockPostRepository(),
            userId: "u1"
        )
        vm.allSessions = [
            SessionModel(userId: "u1", gymName: "Gym", date: Date())
        ]
        XCTAssertGreaterThanOrEqual(vm.weeklyStreak, 1)
    }

    func testLoad() async {
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(currentUserId: "user1"),
            sessionRepository: MockSessionRepository(currentUserId: "user1"),
            storageRepository: MockStorageRepository(),
            postRepository: MockPostRepository(),
            userId: "user1"
        )

        await vm.load()

        XCTAssertNotNil(vm.user)
        XCTAssertFalse(vm.allSessions.isEmpty)
        XCTAssertFalse(vm.recentSessions.isEmpty)
        XCTAssertLessThanOrEqual(vm.recentSessions.count, 10)
        XCTAssertFalse(vm.isLoading)
    }

    func testSaveProfile() async {
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(currentUserId: "user1"),
            sessionRepository: MockSessionRepository(currentUserId: "user1"),
            storageRepository: MockStorageRepository(),
            postRepository: MockPostRepository(),
            userId: "user1"
        )

        await vm.load()
        vm.editDisplayName = "New Name"
        vm.editBio = "New Bio"
        await vm.saveProfile()

        XCTAssertEqual(vm.user?.displayName, "New Name")
        XCTAssertEqual(vm.user?.bio, "New Bio")
        XCTAssertNil(vm.error)
    }
}

// MARK: - Firestore Data Integrity Tests (Logic-only, no network)

final class FirestoreDataIntegrityTests: XCTestCase {

    func testSessionDTOHasAllFirestoreFields() {
        let session = SessionModel(
            userId: "u1", gymName: "Test Gym", durationMinutes: 60,
            notes: "Great", photoURLs: ["url1"]
        )
        session.climbs = [
            ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .flash)
        ]
        session.updateStats()

        let dict = session.toDTO().asDictionary()

        XCTAssertEqual(dict["userId"] as? String, "u1")
        XCTAssertEqual(dict["gymName"] as? String, "Test Gym")
        XCTAssertEqual(dict["durationMinutes"] as? Int, 60)
        XCTAssertEqual(dict["notes"] as? String, "Great")
        XCTAssertEqual(dict["totalClimbs"] as? Int, 1)
        XCTAssertEqual(dict["completedClimbs"] as? Int, 1)
        XCTAssertEqual(dict["highestGrade"] as? String, "V5")
        XCTAssertEqual(dict["highestGradeNumeric"] as? Int, 5)
        XCTAssertNotNil(dict["date"])
        XCTAssertNotNil(dict["createdAt"])
    }

    func testUserDTOHasAllFirestoreFields() {
        let user = UserModel(
            uid: "u1", displayName: "Test", username: "test_user",
            bio: "Bio", profileImageURL: "url", followersCount: 5, followingCount: 3
        )
        let dict = user.toDTO().asDictionary()

        XCTAssertEqual(dict["displayName"] as? String, "Test")
        XCTAssertEqual(dict["username"] as? String, "test_user")
        XCTAssertEqual(dict["bio"] as? String, "Bio")
        XCTAssertEqual(dict["profileImageURL"] as? String, "url")
        XCTAssertEqual(dict["followersCount"] as? Int, 5)
        XCTAssertEqual(dict["followingCount"] as? Int, 3)
        XCTAssertEqual(dict["isPublic"] as? Bool, true)
        XCTAssertNotNil(dict["createdAt"])
    }

    func testClimbOutcomeStoredAsString() {
        let climb = ClimbModel(sessionId: "s1", grade: "V5", gradeNumeric: 5, outcome: .flash)
        let dict = climb.toDTO().asDictionary()

        XCTAssertEqual(dict["outcome"] as? String, "flash")
        XCTAssertEqual(dict["isCompleted"] as? Bool, true)
    }

    func testPostGradeCountsAsDictionary() {
        let post = PostModel(
            userId: "u1", sessionId: "s1", gymName: "Gym",
            topGrade: "V5", topGradeNumeric: 5, totalClimbs: 3,
            gradeCounts: ["V3": 1, "V4": 1, "V5": 1]
        )
        let dict = post.toDTO().asDictionary()
        let counts = dict["gradeCounts"] as? [String: Int]

        XCTAssertNotNil(counts)
        XCTAssertEqual(counts?["V3"], 1)
        XCTAssertEqual(counts?["V5"], 1)
    }
}

// MARK: - Edge Case Tests

final class EdgeCaseTests: XCTestCase {

    func testV0Grade() {
        let climb = ClimbModel(sessionId: "s1", grade: "V0", gradeNumeric: 0, outcome: .flash)
        XCTAssertEqual(climb.grade, "V0")
        XCTAssertEqual(climb.gradeNumeric, 0)
        XCTAssertTrue(climb.isCompleted)
    }

    func testV17Grade() {
        let climb = ClimbModel(sessionId: "s1", grade: "V17", gradeNumeric: 17, outcome: .attempt)
        XCTAssertEqual(climb.grade, "V17")
        XCTAssertEqual(climb.gradeNumeric, 17)
        XCTAssertFalse(climb.isCompleted)
    }

    func testSessionWithManyClimbs() {
        let session = SessionModel(userId: "u1", gymName: "Test")
        for i in 0...10 {
            session.climbs.append(
                ClimbModel(sessionId: session.sessionId, grade: "V\(i)", gradeNumeric: i, outcome: .flash)
            )
        }
        session.updateStats()

        XCTAssertEqual(session.totalClimbs, 11)
        XCTAssertEqual(session.completedClimbs, 11)
        XCTAssertEqual(session.highestGrade, "V10")
        XCTAssertEqual(session.highestGradeNumeric, 10)
    }

    func testUserModelDefaults() {
        let user = UserModel(uid: "test", displayName: "Test", username: "test")
        XCTAssertEqual(user.bio, "")
        XCTAssertEqual(user.profileImageURL, "")
        XCTAssertEqual(user.followersCount, 0)
        XCTAssertEqual(user.followingCount, 0)
        XCTAssertEqual(user.totalSessions, 0)
        XCTAssertEqual(user.totalClimbs, 0)
        XCTAssertEqual(user.highestGrade, "")
        XCTAssertEqual(user.highestGradeNumeric, -1)
        XCTAssertTrue(user.isPublic)
    }

    func testPostModelDefaults() {
        let post = PostModel(userId: "u1", sessionId: "s1")
        XCTAssertEqual(post.likesCount, 0)
        XCTAssertEqual(post.commentsCount, 0)
        XCTAssertFalse(post.isLikedByCurrentUser)
        XCTAssertEqual(post.visibility, "followers")
        XCTAssertEqual(post.type, "session")
        XCTAssertNil(post.imageURL)
    }

    func testUnlikeBelowZero() async throws {
        let repo = MockPostRepository()
        let post = PostModel(userId: "u1", sessionId: "s1", likesCount: 0)
        try await repo.createPost(post)
        try await repo.unlikePost(post.postId, userId: "user1")

        let updated = try await repo.fetchFeed(for: "user1")
        let updatedPost = updated.first { $0.postId == post.postId }!
        XCTAssertEqual(updatedPost.likesCount, 0) // Should not go negative
    }
}

// MARK: - GradeDisplay Tests

final class GradeDisplayTests: XCTestCase {

    // Full canonical table: every V-numeric 0-17 in every system.
    func testVScaleLabels() {
        for n in 0...17 {
            XCTAssertEqual(GradeDisplay.label(for: n, system: .vScale), "V\(n)")
        }
    }

    func testFontLabelsFullTable() {
        let expected = [
            "4", "5", "5+", "6A", "6B", "6C", "7A", "7A+", "7B",
            "7C", "7C+", "8A", "8A+", "8B", "8B+", "8C", "8C+", "9A"
        ]
        for (n, label) in expected.enumerated() {
            XCTAssertEqual(GradeDisplay.label(for: n, system: .font), label, "V\(n) should map to \(label)")
        }
    }

    func testCircuitBands() {
        let expectations: [(Int, String)] = [
            (0, "V0"), (1, "V1–V2"), (2, "V1–V2"),
            (3, "V3–V4"), (4, "V3–V4"),
            (5, "V5–V6"), (6, "V5–V6"),
            (7, "V7–V8"), (8, "V7–V8"),
            (9, "V9–V11"), (10, "V9–V11"), (11, "V9–V11"),
            (12, "V12+"), (17, "V12+")
        ]
        for (n, band) in expectations {
            XCTAssertEqual(GradeDisplay.label(for: n, system: .circuit), band, "V\(n) should band to \(band)")
        }
    }

    func testOutOfRangeNumerics() {
        XCTAssertEqual(GradeDisplay.label(for: -1, system: .vScale), "?")
        XCTAssertEqual(GradeDisplay.label(for: -1, system: .font), "?")
        XCTAssertEqual(GradeDisplay.label(for: -1, system: .circuit), "?")
        XCTAssertEqual(GradeDisplay.label(for: 18, system: .font), "?")
        XCTAssertEqual(GradeDisplay.label(for: 18, system: .circuit), "V12+")
    }

    // Stored-string convenience: converts parseable V-strings, passes through junk.
    func testStoredStringConversion() {
        XCTAssertEqual(GradeDisplay.label(forStored: "V5", system: .font), "6C")
        XCTAssertEqual(GradeDisplay.label(forStored: "V5", system: .circuit), "V5–V6")
        XCTAssertEqual(GradeDisplay.label(forStored: "V5", system: .vScale), "V5")
        XCTAssertEqual(GradeDisplay.label(forStored: "", system: .font), "")
        XCTAssertEqual(GradeDisplay.label(forStored: "garbage", system: .font), "garbage")
    }

    // Canonical invariance: display conversion never changes what would be stored.
    func testCanonicalRoundTripInvariance() {
        for n in 0...17 {
            let stored = VGrade.label(for: n)
            XCTAssertEqual(VGrade.numeric(for: stored), n)
            // Converting for display must not touch the canonical string.
            _ = GradeDisplay.label(forStored: stored, system: .font)
            XCTAssertEqual(stored, "V\(n)")
        }
    }

    // Input controls: Font converts, Circuit falls back to precise V labels.
    func testInputLabelCircuitFallback() {
        let settings = GradeDisplaySettings()
        UserDefaults.standard.removeObject(forKey: GradeDisplaySettings.defaultsKey)
        XCTAssertEqual(settings.system, .vScale)
        XCTAssertEqual(settings.inputLabel(forStored: "V5"), "V5")
    }
}

// MARK: - SuggestionEngine Tests

final class SuggestionEngineTests: XCTestCase {

    private func user(
        _ uid: String,
        name: String? = nil,
        followers: Int = 0,
        grade: Int = -1
    ) -> UserModel {
        UserModel(
            uid: uid,
            displayName: name ?? "User \(uid)",
            username: "user_\(uid)",
            followersCount: followers,
            highestGradeNumeric: grade
        )
    }

    private func signals(
        following: Set<String> = [],
        followers: Set<String> = [],
        friendsOfFriends: [String: [String]] = [:],
        candidateGyms: [String: Set<String>] = [:],
        viewerGyms: Set<String> = [],
        viewerGrade: Int = -1,
        blocked: Set<String> = [],
        demo: Set<String> = []
    ) -> SuggestionSignals {
        SuggestionSignals(
            viewerFollowingIds: following,
            viewerFollowerIds: followers,
            friendsOfFriends: friendsOfFriends,
            candidateGyms: candidateGyms,
            viewerGyms: viewerGyms,
            viewerGradeNumeric: viewerGrade,
            blockedIds: blocked,
            demoIds: demo,
            viewerUid: "viewer"
        )
    }

    func testMutualBeatsGymPlusGradeCombined() {
        let mutual = user("mutual")
        let local = user("local", grade: 5)
        let ranked = SuggestionEngine.rank(
            candidates: [local, mutual],
            signals: signals(
                friendsOfFriends: ["mutual": ["Phuc"]],
                candidateGyms: ["local": ["dogpatch boulders"]],
                viewerGyms: ["dogpatch boulders"],
                viewerGrade: 5
            )
        )
        XCTAssertEqual(ranked.map(\.user.uid), ["mutual", "local"])
        XCTAssertGreaterThan(ranked[0].score, ranked[1].score)
        XCTAssertEqual(ranked[0].reason, .mutualFollow(name: "Phuc"))
        XCTAssertEqual(ranked[0].reason.label, "Followed by Phuc")
    }

    func testFollowsYouOutranksGym() {
        let fan = user("fan")
        let local = user("local")
        let ranked = SuggestionEngine.rank(
            candidates: [local, fan],
            signals: signals(
                followers: ["fan"],
                candidateGyms: ["local": ["dogpatch boulders"]],
                viewerGyms: ["dogpatch boulders"]
            )
        )
        XCTAssertEqual(ranked.map(\.user.uid), ["fan", "local"])
        XCTAssertEqual(ranked[0].reason, .followsYou)
        XCTAssertEqual(ranked[1].reason, .sameGym(gym: "dogpatch boulders"))
    }

    func testReasonPrecedencePicksMutualOverEverything() {
        let ranked = SuggestionEngine.rank(
            candidates: [user("a", grade: 5)],
            signals: signals(
                followers: ["a"],
                friendsOfFriends: ["a": ["Dana"]],
                candidateGyms: ["a": ["dogpatch boulders"]],
                viewerGyms: ["dogpatch boulders"],
                viewerGrade: 5
            )
        )
        XCTAssertEqual(ranked.count, 1)
        // Every signal fires, but the reason is the highest-precedence one.
        XCTAssertEqual(ranked[0].reason, .mutualFollow(name: "Dana"))
        let expectedScore = FeedConfig.suggestionMutualWeight
            + FeedConfig.suggestionFollowsYouWeight
            + FeedConfig.suggestionGymWeight
            + FeedConfig.suggestionGradePeerWeight
        XCTAssertEqual(ranked[0].score, expectedScore, accuracy: 0.001)
    }

    func testExcludedCandidatesNeverAppear() {
        let candidates = [
            user("viewer"),
            user("demo1"),
            user("blocked1"),
            user("followed1"),
            user("fresh")
        ]
        let ranked = SuggestionEngine.rank(
            candidates: candidates,
            signals: signals(
                following: ["followed1"],
                // Signals firing on excluded users must not resurrect them.
                followers: ["blocked1", "demo1"],
                friendsOfFriends: ["followed1": ["Dana"]],
                blocked: ["blocked1"],
                demo: ["demo1"]
            )
        )
        XCTAssertEqual(ranked.map(\.user.uid), ["fresh"])
    }

    func testFollowersCountBreaksTies() {
        // No graph signals for either; uid order alone would put "aa" first.
        let unknown = user("aa", followers: 0)
        let known = user("zz", followers: 100)
        let ranked = SuggestionEngine.rank(candidates: [unknown, known], signals: signals())
        XCTAssertEqual(ranked.map(\.user.uid), ["zz", "aa"])
        XCTAssertTrue(ranked.allSatisfy { $0.reason == .popular })
    }

    func testEmptySignalsFallBackToPopular() {
        let ranked = SuggestionEngine.rank(candidates: [user("a")], signals: signals())
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked[0].reason, .popular)
        XCTAssertEqual(ranked[0].reason.label, "Popular in the community")
        XCTAssertEqual(ranked[0].score, 0, accuracy: 0.001)
    }

    func testGradePeerOnlyWithinWindow() {
        let viewerGrade = 5
        let inWindow = viewerGrade + FeedConfig.gradeProximityWindow
        let outOfWindow = viewerGrade + FeedConfig.gradeProximityWindow + 1

        let ranked = SuggestionEngine.rank(
            candidates: [user("near", grade: inWindow), user("far", grade: outOfWindow)],
            signals: signals(viewerGrade: viewerGrade)
        )
        XCTAssertEqual(ranked.map(\.user.uid), ["near", "far"])
        XCTAssertEqual(ranked[0].reason, .gradePeer(numeric: inWindow))
        XCTAssertEqual(ranked[1].reason, .popular)

        // No viewer grade → no peers at all.
        let ungraded = SuggestionEngine.rank(
            candidates: [user("near", grade: inWindow)],
            signals: signals(viewerGrade: -1)
        )
        XCTAssertEqual(ungraded[0].reason, .popular)
    }

    func testMutualScoreCapsAtThree() {
        let ranked = SuggestionEngine.rank(
            candidates: [user("a"), user("b")],
            signals: signals(friendsOfFriends: [
                "a": ["One", "Two", "Three", "Four", "Five"],
                "b": ["One", "Two", "Three"]
            ])
        )
        XCTAssertEqual(ranked[0].score, ranked[1].score, accuracy: 0.001)
    }
}


// MARK: - Post Climb Sequence Tests

final class PostClimbSequenceTests: XCTestCase {

    private func makePost(gradeSequence: [String], outcomeSequence: [String], gradeCounts: [String: Int] = [:]) -> PostModel {
        PostModel(
            userId: "u1",
            sessionId: "s1",
            gradeCounts: gradeCounts,
            gradeSequence: gradeSequence,
            outcomeSequence: outcomeSequence
        )
    }

    func testAllAttemptSessionHasNonEmptySequence() {
        // Regression: gating on gradeCounts hid all-attempt sessions entirely.
        let post = makePost(
            gradeSequence: ["V4", "V4", "V5"],
            outcomeSequence: ["attempt", "attempt", "attempt"]
        )
        XCTAssertTrue(post.gradeCounts.isEmpty)
        XCTAssertEqual(post.climbSequence.count, 3)
        let tally = post.outcomeTally
        XCTAssertEqual(tally.sends, 0)
        XCTAssertEqual(tally.flashes, 0)
        XCTAssertEqual(tally.attempts, 3)
    }

    func testLegacyGradeCountsFallback() {
        let post = makePost(gradeSequence: [], outcomeSequence: [], gradeCounts: ["V3": 2, "V5": 1])
        let sequence = post.climbSequence
        XCTAssertEqual(sequence.count, 3)
        XCTAssertEqual(sequence.map(\.grade), ["V3", "V3", "V5"])
        XCTAssertTrue(sequence.allSatisfy { $0.outcome == .sent })
    }

    func testShortSessionsStayUngrouped() {
        let post = makePost(
            gradeSequence: ["V3", "V3", "V3"],
            outcomeSequence: ["sent", "sent", "sent"]
        )
        let chips = post.groupedChips()
        XCTAssertEqual(chips.count, 3)
        XCTAssertTrue(chips.allSatisfy { $0.count == 1 })
    }

    func testLongSessionsGroupConsecutiveRuns() {
        // 10 climbs: V3 sent x3, V3 attempt x2, V3 sent x2, V4 sent x3 —
        // sends and attempts at the same grade never merge; non-adjacent
        // repeats stay separate (RLE, not a histogram).
        let grades = ["V3","V3","V3","V3","V3","V3","V3","V4","V4","V4"]
        let outcomes = ["sent","sent","sent","attempt","attempt","sent","sent","sent","sent","sent"]
        let chips = makePost(gradeSequence: grades, outcomeSequence: outcomes).groupedChips()
        XCTAssertEqual(chips.map(\.count), [3, 2, 2, 3])
        XCTAssertEqual(chips[0].outcome, .sent)
        XCTAssertEqual(chips[1].outcome, .attempt)
        XCTAssertEqual(chips[2].outcome, .sent)
        XCTAssertEqual(chips[3].grade, "V4")
    }

    func testMissingOutcomeIndexDefaultsToSent() {
        let post = makePost(gradeSequence: ["V2", "V3"], outcomeSequence: ["flash"])
        let sequence = post.climbSequence
        XCTAssertEqual(sequence[0].outcome, .flash)
        XCTAssertEqual(sequence[1].outcome, .sent)
    }

    func testDurationFormatting() {
        XCTAssertEqual(SessionStripView.formatDuration(45), "45m")
        XCTAssertEqual(SessionStripView.formatDuration(60), "1h")
        XCTAssertEqual(SessionStripView.formatDuration(95), "1h 35m")
    }

    func testPostDTORoundtripWithDuration() {
        let post = makePost(gradeSequence: ["V3"], outcomeSequence: ["sent"])
        post.sessionDurationMinutes = 95
        let dict = post.toDTO().asDictionary()
        XCTAssertEqual(dict["sessionDurationMinutes"] as? Int, 95)
    }

    func testPostDTOOmitsNilDuration() {
        let post = makePost(gradeSequence: ["V3"], outcomeSequence: ["sent"])
        XCTAssertNil(post.sessionDurationMinutes)
        let dict = post.toDTO().asDictionary()
        XCTAssertNil(dict["sessionDurationMinutes"])
    }
}
