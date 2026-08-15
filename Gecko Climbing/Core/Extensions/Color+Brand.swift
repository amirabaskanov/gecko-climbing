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
    // Semantic hues (gold=flash, green=sent, blue=attempt) tuned so each also
    // works as TEXT on the cream/dark backgrounds at ≥4.5:1 — the previous
    // #4CAF50/#42A5F5 sat at ~2.6:1 as text. Sent green deliberately shares no
    // hex with any grade bucket (the old ramp's V0–V2 green collided with it).
    static let geckoSentGreen = Color.dynamic(light: "#35803D", dark: "#5FBF66")
    static let geckoSentGreenLight = Color(hex: "#81C784")
    static let geckoFlashGold = Color.dynamic(light: "#E6AC00", dark: "#FFC933")
    /// Flash gold when used as text on the cream background (fills keep
    /// geckoFlashGold; raw gold text on cream is ~2.9:1).
    static let geckoFlashGoldDeep = Color.dynamic(light: "#8A6A00", dark: "#FFC933")
    static let geckoFlashGoldLight = Color(hex: "#FFD700")
    static let geckoAttemptBlue = Color.dynamic(light: "#1B72B5", dark: "#64B5F6")
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

    // MARK: - Grade Colors ("Approach to Summit" ramp)
    // Hue walks the CVD-preserved blue↔yellow axis (chalk-slate → sandstone →
    // copper → ember → dusk violet → basalt) while relative luminance descends
    // strictly monotonically (0.39 → 0.32 → 0.25 → 0.11 → 0.07 → 0.02), so the
    // "harder = darker/hotter" ordering survives deuteranopia, protanopia, and
    // full grayscale on lightness alone. No green anywhere in the ramp, so the
    // sent-state green can never be mistaken for an easy grade.
    static func gradeColor(for gradeNumeric: Int) -> Color {
        switch gradeNumeric {
        case 0...2:  return Color(hex: "#86ADC8")                          // Slate
        case 3...4:  return Color(hex: "#C09140")                          // Sandstone
        case 5...6:  return Color(hex: "#C97231")                          // Copper
        case 7...8:  return Color.dynamic(light: "#A63A22", dark: "#C1482B") // Ember
        case 9...11: return Color.dynamic(light: "#5E3A78", dark: "#7E57A0") // Dusk
        default:     return Color.dynamic(light: "#1E2A26", dark: "#E9EDEB") // Basalt / Chalk
        }
    }

    static func gradeColor(for grade: String) -> Color {
        let numeric = VGrade.numeric(for: grade)
        return gradeColor(for: numeric)
    }

    /// Flat by design — the design language uses confident flat fills, not
    /// gradients. Kept as a LinearGradient so ShapeStyle call sites don't
    /// churn; both stops are the bucket color.
    static func gradeGradient(for gradeNumeric: Int) -> LinearGradient {
        let base = gradeColor(for: gradeNumeric)
        return LinearGradient(
            colors: [base, base],
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

    /// Text color on top of `Color.gradeColor` fills. Light buckets (slate,
    /// sandstone, copper) take ink; dark buckets take white; the 12+ terminal
    /// flips with the fill (basalt fill in light mode → white text, chalk fill
    /// in dark mode → ink). All pairings ≥4.5:1.
    static func textColor(for gradeNumeric: Int) -> Color {
        switch gradeNumeric {
        case 0...6:  return Color(hex: "#10181A")
        case 7...11: return .white
        default:     return Color.dynamic(light: "#FFFFFF", dark: "#10181A")
        }
    }
}
