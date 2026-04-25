import Foundation
import UIKit

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
}
