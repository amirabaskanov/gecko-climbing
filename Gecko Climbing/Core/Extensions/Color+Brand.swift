import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let geckoGreen = Color(hex: "#4CAF50")
    static let geckoGreenLight = Color(hex: "#81C784")
    static let geckoGreenDark = Color(hex: "#388E3C")
    static let geckoOrange = Color(hex: "#FF6B6B")
    static let geckoBackground = Color(hex: "#F5F5F0")
    static let geckoCard = Color.white
    static let geckoSecondaryText = Color(hex: "#9E9E9E")
    static let geckoFlashGold = Color(hex: "#FFD700")
    static let geckoProjectBlue = Color(hex: "#2196F3")
    static let geckoAttemptBlue = Color(hex: "#42A5F5")

    // MARK: - Surface System
    static let surface = Color.white
    static let surfaceElevated = Color(hex: "#FAFAF7")
    static let surfaceBackground = Color(hex: "#F5F5F0")

    // MARK: - Gradients
    static var geckoGreenGradient: LinearGradient {
        LinearGradient(colors: [geckoGreen, geckoGreenDark], startPoint: .top, endPoint: .bottom)
    }

    static var warmGlow: LinearGradient {
        LinearGradient(colors: [geckoFlashGold, Color(hex: "#FF9800")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Outcome Gradients
    static func outcomeGradient(for outcome: ClimbOutcome) -> LinearGradient {
        switch outcome {
        case .flash:
            return LinearGradient(colors: [geckoFlashGold, Color(hex: "#FFA000")], startPoint: .top, endPoint: .bottom)
        case .sent:
            return LinearGradient(colors: [geckoGreen, geckoGreenDark], startPoint: .top, endPoint: .bottom)
        case .project:
            return LinearGradient(colors: [geckoProjectBlue, Color(hex: "#1565C0")], startPoint: .top, endPoint: .bottom)
        case .attempt:
            return LinearGradient(colors: [geckoAttemptBlue, Color(hex: "#1E88E5")], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Grade Colors (difficulty gradient)
    static func gradeColor(for gradeNumeric: Int) -> Color {
        switch gradeNumeric {
        case 0...2:  return Color(hex: "#4CAF50") // Green
        case 3...4:  return Color(hex: "#FFC107") // Yellow
        case 5...6:  return Color(hex: "#FF9800") // Orange
        case 7...8:  return Color(hex: "#F44336") // Red
        case 9...11: return Color(hex: "#9C27B0") // Purple
        default:     return Color(hex: "#212121") // Black
        }
    }

    static func gradeColor(for grade: String) -> Color {
        let numeric = VGrade.numeric(for: grade)
        return gradeColor(for: numeric)
    }

    static func gradeGradient(for gradeNumeric: Int) -> LinearGradient {
        let base = gradeColor(for: gradeNumeric)
        return LinearGradient(
            colors: [base.opacity(0.85), base],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - VGrade Helpers
enum VGrade {
    static let all: [String] = (0...17).map { $0 == 0 ? "V0" : "V\($0)" }
    static let standard: [String] = (0...10).map { "V\($0)" }

    static func numeric(for grade: String) -> Int {
        let trimmed = grade.uppercased().replacingOccurrences(of: "V", with: "")
        return Int(trimmed) ?? -1
    }

    static func label(for numeric: Int) -> String {
        guard numeric >= 0 && numeric <= 17 else { return "?" }
        return "V\(numeric)"
    }

    static func textColor(for gradeNumeric: Int) -> Color {
        gradeNumeric >= 12 ? .white : .white
    }
}
