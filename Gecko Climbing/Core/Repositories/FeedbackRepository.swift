import Foundation
import UIKit

// MARK: - Report Model
//
// Lives in this file (instead of Core/Models) so it ships in the Xcode build
// target without needing a project-file edit. The `reports` Firestore
// collection is owned by FeedbackRepository conceptually, so the colocation
// reads naturally too.

/// A user-submitted report of objectionable content. Required by App Store
/// Review Guideline 1.2 (Safety – User-Generated Content). Lives in the
/// `reports` Firestore collection; triage happens out-of-band via the
/// Firebase console.
struct ReportModel: Identifiable, Sendable {
    let id: String
    let reporterUserId: String
    let targetType: TargetType
    let targetId: String
    /// Parent post id when the target is a comment. Equal to `targetId` for
    /// post targets; nil for user-level reports.
    let targetPostId: String?
    let targetAuthorId: String
    let reason: Reason
    let createdAt: Date

    enum TargetType: String, Sendable {
        case post, comment, user
    }

    enum Reason: String, CaseIterable, Identifiable, Sendable {
        case spam = "Spam or fake"
        case harassment = "Harassment or bullying"
        case inappropriate = "Inappropriate content"
        case impersonation = "Impersonation"
        case other = "Something else"

        var id: String { rawValue }
    }

    init(
        id: String = UUID().uuidString,
        reporterUserId: String,
        targetType: TargetType,
        targetId: String,
        targetPostId: String? = nil,
        targetAuthorId: String,
        reason: Reason,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.reporterUserId = reporterUserId
        self.targetType = targetType
        self.targetId = targetId
        self.targetPostId = targetPostId
        self.targetAuthorId = targetAuthorId
        self.reason = reason
        self.createdAt = createdAt
    }
}

// MARK: - Feedback Category

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "bug"
    case feature = "feature"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: "Bug Report"
        case .feature: "Feature Idea"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .bug: "ladybug"
        case .feature: "lightbulb"
        case .other: "ellipsis.bubble"
        }
    }

    var placeholder: String {
        switch self {
        case .bug: "What went wrong? What were you doing when it happened?"
        case .feature: "What would you like to see in Gecko?"
        case .other: "Tell us what's on your mind..."
        }
    }
}

// MARK: - Device Info

struct DeviceInfo {
    static var current: [String: String] {
        [
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "iosVersion": UIDevice.current.systemVersion,
            "deviceModel": UIDevice.current.model,
            "deviceName": UIDevice.current.name
        ]
    }
}

// MARK: - Protocol

protocol FeedbackRepositoryProtocol: AnyObject {
    func submitFeedback(
        userId: String,
        category: FeedbackCategory,
        message: String,
        screenshotData: Data?
    ) async throws

    /// Submit a user-generated report of objectionable content. Required by
    /// App Store Review Guideline 1.2 (Safety – UGC). Reports land in the
    /// `reports` Firestore collection; triage happens via the Firebase
    /// console.
    func submitReport(_ report: ReportModel) async throws
}

// MARK: - Mock Implementation

final class MockFeedbackRepository: FeedbackRepositoryProtocol, @unchecked Sendable {
    func submitFeedback(
        userId: String,
        category: FeedbackCategory,
        message: String,
        screenshotData: Data?
    ) async throws {
        try await Task.sleep(nanoseconds: 800_000_000)
        #if DEBUG
        print("📝 [Mock] Feedback submitted: [\(category.rawValue)] \(message)")
        #endif
    }

    func submitReport(_ report: ReportModel) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
        #if DEBUG
        print("🚩 [Mock] Report submitted: \(report.targetType.rawValue) \(report.targetId) — \(report.reason.rawValue)")
        #endif
    }
}
