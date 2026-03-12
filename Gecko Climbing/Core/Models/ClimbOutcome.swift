import SwiftUI

enum ClimbOutcome: String, Codable, CaseIterable, Identifiable {
    case flash, sent, project, attempt

    var id: String { rawValue }

    /// Custom decoding to handle legacy "fail" values stored in SwiftData
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ClimbOutcome.fromString(raw)
    }

    /// Resolve legacy "fail" strings to .attempt
    static func fromString(_ raw: String) -> ClimbOutcome {
        if raw == "fail" { return .attempt }
        return ClimbOutcome(rawValue: raw) ?? .attempt
    }

    var label: String {
        switch self {
        case .flash:   return "Flash"
        case .sent:    return "Sent"
        case .project: return "Project"
        case .attempt: return "Attempt"
        }
    }

    var icon: String {
        switch self {
        case .flash:   return "bolt.fill"
        case .sent:    return "checkmark.circle.fill"
        case .project: return "wrench.and.screwdriver.fill"
        case .attempt: return "arrow.trianglehead.counterclockwise"
        }
    }

    var color: Color {
        switch self {
        case .flash:   return .geckoFlashGold
        case .sent:    return .geckoSentGreen
        case .project: return .geckoProjectBlue
        case .attempt: return .geckoAttemptBlue
        }
    }

    var isCompleted: Bool {
        switch self {
        case .flash, .sent: return true
        case .project, .attempt: return false
        }
    }

    var defaultAttempts: Int {
        switch self {
        case .flash: return 1
        case .sent:  return 2
        case .project, .attempt: return 1
        }
    }

    var minAttempts: Int {
        switch self {
        case .flash: return 1
        case .sent:  return 2
        case .project, .attempt: return 1
        }
    }
}
