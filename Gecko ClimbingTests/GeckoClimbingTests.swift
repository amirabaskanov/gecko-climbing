import XCTest
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
            type: "session", caption: "Test", imageURL: nil,
            likesCount: 0, commentsCount: 0, createdAt: Date(),
            topGrade: "V5", topGradeNumeric: 5, totalClimbs: 1,
            gradeCounts: ["V5": 1], visibility: "followers"
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
            XCTAssertEqual(error, .emailAlreadyInUse)
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

        let before = try await repo.isFollowing(targetUID: "friend_1")
        XCTAssertFalse(before)

        try await repo.follow(targetUID: "friend_1")
        let afterFollow = try await repo.isFollowing(targetUID: "friend_1")
        XCTAssertTrue(afterFollow)

        let following = try await repo.fetchFollowing(uid: "user1")
        XCTAssertTrue(following.contains { $0.uid == "friend_1" })

        try await repo.unfollow(targetUID: "friend_1")
        let afterUnfollow = try await repo.isFollowing(targetUID: "friend_1")
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
        let results = try await repo.searchUsers(query: "Sam")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.displayName, "Sam Rocks")
    }

    func testSearchEmptyQuery() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        let results = try await repo.searchUsers(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testFollowIncrementsCount() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        let beforeUser = try await repo.fetchUser(uid: "friend_1")
        let beforeCount = beforeUser.followersCount

        try await repo.follow(targetUID: "friend_1")
        let afterUser = try await repo.fetchUser(uid: "friend_1")

        XCTAssertEqual(afterUser.followersCount, beforeCount + 1)
    }

    func testUnfollowDoesNotGoNegative() async throws {
        let repo = MockUserRepository(currentUserId: "user1")
        // Unfollow someone we're not following — count should not go below 0
        let beforeUser = try await repo.fetchUser(uid: "friend_1")
        _ = beforeUser.followersCount

        try await repo.unfollow(targetUID: "friend_1")
        let afterUser = try await repo.fetchUser(uid: "friend_1")
        XCTAssertGreaterThanOrEqual(afterUser.followersCount, 0)
    }
}

// MARK: - Mock Post Repository Tests

final class MockPostRepositoryTests: XCTestCase {

    func testSeedFeedHasPosts() async throws {
        let repo = MockPostRepository()
        let posts = try await repo.fetchFeed(for: "user1")
        XCTAssertEqual(posts.count, 5)
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

final class HomeViewModelTests: XCTestCase {

    func testLoadFeedPopulatesPosts() async {
        let repo = MockPostRepository()
        let vm = HomeViewModel(postRepository: repo, userId: "user1")

        await vm.loadFeed()

        XCTAssertFalse(vm.posts.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    func testToggleLikeFlipsState() async {
        let repo = MockPostRepository()
        let vm = HomeViewModel(postRepository: repo, userId: "user1")

        await vm.loadFeed()
        guard let post = vm.posts.first else {
            XCTFail("No posts in feed")
            return
        }

        let wasLiked = post.isLikedByCurrentUser

        await vm.toggleLike(post)

        let updated = vm.posts.first { $0.postId == post.postId }!
        XCTAssertEqual(updated.isLikedByCurrentUser, !wasLiked)
    }

    func testToggleLikeNonExistentPost() async {
        let repo = MockPostRepository()
        let vm = HomeViewModel(postRepository: repo, userId: "user1")
        await vm.loadFeed()

        let fakePost = PostModel(postId: "nonexistent", userId: "u1", sessionId: "s1")
        await vm.toggleLike(fakePost)
        // Should not crash, just no-op
    }
}

// MARK: - StatsViewModel Tests

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
}

// MARK: - SessionDetailViewModel Tests

final class SessionDetailViewModelTests: XCTestCase {

    func testSortedClimbsChronological() {
        let session = SessionModel(userId: "u1", gymName: "Test")
        let older = ClimbModel(sessionId: session.sessionId, grade: "V3", gradeNumeric: 3, outcome: .flash, loggedAt: Date().addingTimeInterval(-3600))
        let newer = ClimbModel(sessionId: session.sessionId, grade: "V5", gradeNumeric: 5, outcome: .sent, attempts: 2, loggedAt: Date())
        session.climbs = [newer, older]

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"))

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

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"))

        XCTAssertEqual(vm.flashes.count, 1)
        XCTAssertEqual(vm.sends.count, 1)
        XCTAssertEqual(vm.fails.count, 2) // both attempts
    }

    func testAddClimb() async {
        let session = SessionModel(userId: "u1", gymName: "Test")
        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"))

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

        let vm = SessionDetailViewModel(session: session, sessionRepository: MockSessionRepository(currentUserId: "u1"))
        await vm.deleteClimb(climb)

        XCTAssertTrue(vm.session.climbs.isEmpty)
        XCTAssertEqual(vm.session.totalClimbs, 0)
    }
}

// MARK: - SocialViewModel Tests

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

        await vm.follow(user: UserModel(uid: "friend_1", displayName: "Sam", username: "sam"))
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

final class ProfileViewModelTests: XCTestCase {

    func testWeeklyStreakNoSessions() {
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(currentUserId: "u1"),
            sessionRepository: MockSessionRepository(currentUserId: "u1"),
            storageRepository: MockStorageRepository(),
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
