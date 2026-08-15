import SwiftUI

// MARK: - Grade System (display preference)

/// The three ways Gecko can *display* bouldering grades. The canonical stored
/// value everywhere (models, DTOs, Firestore) is always the V-scale numeric
/// (`gradeNumeric`, 0–17) — switching systems never rewrites data, it only
/// changes how grades render for the viewer.
enum GradeSystem: String, CaseIterable, Codable, Sendable {
    case vScale
    case font
    case circuit

    var displayName: String {
        switch self {
        case .vScale:  return "V Scale"
        case .font:    return "Fontainebleau"
        case .circuit: return "Circuit"
        }
    }

    var subtitle: String {
        switch self {
        case .vScale:  return "V0–V17 · used in the USA"
        case .font:    return "4–9A · used in Europe"
        case .circuit: return "Grade ranges, gym-circuit style"
        }
    }

    /// A quick "V5 → 6C" style preview line for the Settings picker.
    var previewText: String {
        switch self {
        case .vScale:  return "V5 stays V5"
        case .font:    return "V5 → \(GradeDisplay.label(for: 5, system: .font))"
        case .circuit: return "V5 → \(GradeDisplay.label(for: 5, system: .circuit))"
        }
    }
}

// MARK: - Grade Display (conversion tables)

enum GradeDisplay {
    /// Fontainebleau equivalents for canonical V-numerics 0–17. V↔Font is not
    /// 1:1 (V4 straddles 6B/6B+, V5 straddles 6C/6C+, V8 straddles 7B/7B+);
    /// ties resolve to the lower Font grade so a displayed send is never
    /// overstated.
    private static let fontLabels: [String] = [
        "4",   // V0
        "5",   // V1
        "5+",  // V2
        "6A",  // V3
        "6B",  // V4 (tie: 6B/6B+)
        "6C",  // V5 (tie: 6C/6C+)
        "7A",  // V6
        "7A+", // V7
        "7B",  // V8 (tie: 7B/7B+)
        "7C",  // V9
        "7C+", // V10
        "8A",  // V11
        "8A+", // V12
        "8B",  // V13
        "8B+", // V14
        "8C",  // V15
        "8C+", // V16
        "9A",  // V17
    ]

    /// Circuit bands intentionally mirror the `Color.gradeColor` buckets so a
    /// redesign of the grade color ramp flows through to circuit labels'
    /// colors automatically.
    static func circuitBand(for numeric: Int) -> String {
        switch numeric {
        case ..<0:   return "?"
        case 0...2:  return "VB–V2"
        case 3...4:  return "V3–V4"
        case 5...6:  return "V5–V6"
        case 7...8:  return "V7–V8"
        case 9...11: return "V9–V11"
        default:     return "V12+"
        }
    }

    static func label(for numeric: Int, system: GradeSystem) -> String {
        switch system {
        case .vScale:
            return VGrade.label(for: numeric)
        case .font:
            guard numeric >= 0 && numeric < fontLabels.count else { return "?" }
            return fontLabels[numeric]
        case .circuit:
            return circuitBand(for: numeric)
        }
    }

    /// Convenience for call sites that only have a stored V-scale string
    /// (denormalized post fields like `gradeSequence`). Unparseable strings
    /// pass through untouched rather than rendering "?" over real data.
    static func label(forStored grade: String, system: GradeSystem) -> String {
        guard system != .vScale, !grade.isEmpty else { return grade }
        let numeric = VGrade.numeric(for: grade)
        guard numeric >= 0 else { return grade }
        return label(for: numeric, system: system)
    }
}

// MARK: - Grade Display Settings (viewer preference store)

/// App-wide observable store for the viewer's grade-system preference.
///
/// Reading `GradeDisplaySettings.shared.system` inside a view body registers
/// observation, so every grade label in the app re-renders when the setting
/// changes. The value mirrors synchronously through UserDefaults (instant
/// launch reads) and syncs to `users/{uid}.displayPrefs.gradeSystem` so the
/// preference follows the account across devices — and so Cloud Functions can
/// format push-notification copy per recipient.
@Observable
final class GradeDisplaySettings {
    static let shared = GradeDisplaySettings()
    static let defaultsKey = "gradeSystem"

    private(set) var system: GradeSystem

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        system = stored.flatMap(GradeSystem.init(rawValue:)) ?? .vScale
    }

    func label(for numeric: Int) -> String {
        GradeDisplay.label(for: numeric, system: system)
    }

    func label(forStored grade: String) -> String {
        GradeDisplay.label(forStored: grade, system: system)
    }

    /// Label for grade *input* controls (barrel, picker). Circuit is a display
    /// banding, not an input scale — several V-grades share one band, so
    /// pickers fall back to precise V labels while Font (1:1 per numeric)
    /// converts normally.
    func inputLabel(forStored grade: String) -> String {
        system == .circuit ? grade : label(forStored: grade)
    }

    /// Pull the account-level preference after sign-in. The local mirror keeps
    /// rendering until the fetch lands; a fetch failure changes nothing.
    @MainActor
    func sync(userRepository: any UserRepositoryProtocol, userId: String) async {
        guard let remote = try? await userRepository.fetchGradeSystem(for: userId) else { return }
        if remote != system {
            system = remote
            UserDefaults.standard.set(remote.rawValue, forKey: Self.defaultsKey)
        }
    }

    /// Optimistic update with rollback on write failure. Returns the error (if
    /// any) so Settings can surface it.
    @MainActor
    @discardableResult
    func update(_ newSystem: GradeSystem, userRepository: any UserRepositoryProtocol, userId: String) async -> Error? {
        let previous = system
        system = newSystem
        UserDefaults.standard.set(newSystem.rawValue, forKey: Self.defaultsKey)
        guard !userId.isEmpty else { return nil }
        do {
            try await userRepository.updateGradeSystem(newSystem, for: userId)
            return nil
        } catch {
            system = previous
            UserDefaults.standard.set(previous.rawValue, forKey: Self.defaultsKey)
            return error
        }
    }
}
