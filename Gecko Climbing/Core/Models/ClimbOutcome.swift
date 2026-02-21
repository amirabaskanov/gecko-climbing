import SwiftUI

enum ClimbOutcome: String, Codable, CaseIterable, Identifiable {
    case flash, sent, project, fail

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flash:   return "Flash"
        case .sent:    return "Sent"
        case .project: return "Project"
        case .fail:    return "Fail"
        }
    }

    var icon: String {
        switch self {
        case .flash:   return "bolt.fill"
        case .sent:    return "checkmark.circle.fill"
        case .project: return "wrench.and.screwdriver.fill"
        case .fail:    return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .flash:   return .geckoFlashGold
        case .sent:    return .geckoGreen
        case .project: return .geckoProjectBlue
        case .fail:    return .geckoOrange
        }
    }

    var isCompleted: Bool {
        switch self {
        case .flash, .sent: return true
        case .project, .fail: return false
        }
    }

    var defaultAttempts: Int {
        switch self {
        case .flash: return 1
        case .sent:  return 2
        case .project, .fail: return 1
        }
    }

    var minAttempts: Int {
        switch self {
        case .flash: return 1
        case .sent:  return 2
        case .project, .fail: return 1
        }
    }
}
