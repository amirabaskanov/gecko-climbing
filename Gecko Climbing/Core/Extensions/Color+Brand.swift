import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand Colors (Adaptive Forest)
    /// Primary brand. Deep forest green in light mode, brighter mint-forest in dark mode
    /// so it remains legible against dark surfaces while still reading as "Gecko green."
    static let geckoPrimary = Color.dynamic(light: "#2A6B55", dark: "#3FA07F")
    static let geckoPrimaryLight = Color.dynamic(light: "#3D8A6E", dark: "#5FB898")
    static let geckoPrimaryDark = Color.dynamic(light: "#1F5242", dark: "#2F8566")
    static let geckoMint = Color.dynamic(light: "#B8DFD0", dark: "#7FD1B0")
    static let geckoDeepForest = Color.dynamic(light: "#132E25", dark: "#0A1713")

    // MARK: - Outcome Colors
    // These are vivid accents and work well in both modes; they stay fixed so
    // "gold flash" / "green sent" etc. read consistently across screens.
    static let geckoSentGreen = Color(hex: "#4CAF50")
    static let geckoSentGreenLight = Color(hex: "#81C784")
    static let geckoFlashGold = Color.dynamic(light: "#E6AC00", dark: "#FFC933")
    static let geckoFlashGoldLight = Color(hex: "#FFD700")
    static let geckoAttemptBlue = Color.dynamic(light: "#42A5F5", dark: "#64B5F6")
    static let geckoOrange = Color(hex: "#FF6B6B")

    // MARK: - Surface System (fully adaptive)
    /// Main screen background. Warm cream in light, near-black forest in dark.
    static let geckoBackground = Color.dynamic(light: "#FAF8F5", dark: "#0E1512")
    /// Card / elevated surface. Pure white in light, tinted charcoal in dark.
    static let geckoCard = Color.dynamic(light: "#FFFFFF", dark: "#1A2420")
    /// Slightly raised surface (modals, grouped cells).
    static let geckoSurfaceElevated = Color.dynamic(light: "#FAFAF7", dark: "#222E29")
    /// Input field fill — subtly tinted vs the main background.
    static let geckoInputBackground = Color.dynamic(light: "#F3F0EB", dark: "#1F2925")
    /// Hairline divider / border.
    static let geckoDivider = Color.dynamic(light: "#E8E4DD", dark: "#2B3732")
    /// Secondary / supporting text. Darker in light mode for AA contrast, softer in dark.
    static let geckoSecondaryText = Color.dynamic(light: "#6B6B6B", dark: "#A8B0AC")

    // MARK: - Gradients
    static var geckoPrimaryGradient: LinearGradient {
        LinearGradient(colors: [geckoPrimary, geckoPrimaryDark], startPoint: .top, endPoint: .bottom)
    }

    static var warmGlow: LinearGradient {
        LinearGradient(colors: [geckoFlashGold, Color(hex: "#FF9800")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Outcome Gradients
    static func outcomeGradient(for outcome: ClimbOutcome) -> LinearGradient {
        switch outcome {
        case .flash:
            return LinearGradient(colors: [geckoFlashGoldLight, geckoFlashGold], startPoint: .top, endPoint: .bottom)
        case .sent:
            return LinearGradient(colors: [geckoSentGreen, Color(hex: "#388E3C")], startPoint: .top, endPoint: .bottom)
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
        default:     return Color.dynamic(light: "#212121", dark: "#E0E0E0")
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

    // MARK: - Dynamic color helper
    /// Builds a `Color` that resolves to the `light` hex in light mode and the `dark`
    /// hex in dark mode, following the system trait collection automatically.
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
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

// MARK: - UIColor hex helper (used by dynamic providers)
private extension UIColor {
    convenience init(hex: String) {
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
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
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
        switch gradeNumeric {
        case 3...4: return Color(hex: "#3E2723") // dark brown on yellow/amber
        default:    return .white
        }
    }
}
