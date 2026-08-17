import SwiftUI

// MARK: - Diagonal stripes (attempt texture)

/// Shared hatch texture marking un-sent attempts wherever climbs render —
/// strip segments, chips, pills. Pattern-coding keeps outcomes readable
/// regardless of the grade color underneath.
struct DiagonalStripes: Shape {
    var spacing: CGFloat = 5
    var lineWidth: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = spacing + lineWidth
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += step
        }
        return path
    }
}

// MARK: - Session Strip

/// The feed card's session fingerprint: one slim bar, one equal-width segment
/// per climb in logging order, colored by grade — with the Gym Tape palette it
/// reads like a strip of route tape. Attempts render as a pale hatched
/// segment. A 3-climb and a 25-climb session occupy identical space.
struct SessionStripView: View {
    let climbs: [PostClimb]
    var durationMinutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            strip
            statLine
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var strip: some View {
        HStack(spacing: climbs.count > 20 ? 1 : 2) {
            ForEach(Array(climbs.enumerated()), id: \.offset) { _, climb in
                segment(climb)
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
    }

    private func segment(_ climb: PostClimb) -> some View {
        let color = Color.gradeColor(for: climb.grade)
        let isAttempt = climb.outcome == .attempt
        return ZStack {
            Rectangle()
                .fill(color.opacity(isAttempt ? 0.30 : 1.0))
            if isAttempt {
                DiagonalStripes(spacing: 3, lineWidth: 1)
                    .stroke(color.opacity(0.9), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statLine: some View {
        let tally = tally
        return HStack(spacing: 4) {
            statText("\(climbs.count) \(climbs.count == 1 ? "climb" : "climbs")")
            if tally.sends > 0 {
                dot
                statText("\(tally.sends) \(tally.sends == 1 ? "send" : "sends")")
            }
            if tally.flashes > 0 {
                dot
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.geckoFlashGoldDeep)
                    statText("\(tally.flashes)")
                }
            }
            if let durationMinutes, durationMinutes > 0 {
                dot
                statText(Self.formatDuration(durationMinutes))
            }
            Spacer(minLength: 0)
        }
    }

    private func statText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.geckoSecondaryText)
    }

    private var dot: some View {
        Text("·")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.geckoSecondaryText.opacity(0.6))
    }

    private var tally: (sends: Int, flashes: Int, attempts: Int) {
        var sends = 0, flashes = 0, attempts = 0
        for climb in climbs {
            switch climb.outcome {
            case .flash:   flashes += 1
            case .sent:    sends += 1
            case .attempt: attempts += 1
            }
        }
        return (sends, flashes, attempts)
    }

    static func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
    }

    private var accessibilitySummary: String {
        let tally = tally
        var parts = ["\(climbs.count) climbs", "\(tally.sends) sends"]
        if tally.flashes > 0 { parts.append("\(tally.flashes) flashes") }
        if tally.attempts > 0 { parts.append("\(tally.attempts) attempts") }
        if let durationMinutes, durationMinutes > 0 { parts.append(Self.formatDuration(durationMinutes)) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Climb Chip

/// Hold-shaped chip for a single climb (or a ×N run of identical climbs).
/// Used by the feed card's expanded state and the post detail breakdown.
struct ClimbChipView: View {
    let grade: String
    let outcome: ClimbOutcome
    var count: Int = 1

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        let numeric = VGrade.numeric(for: grade)
        let color = Color.gradeColor(for: numeric)
        let isAttempt = outcome == .attempt
        let ink = VGrade.textColor(for: numeric)
        // Attempt chips sit on a pale tint, so their label uses adaptive ink,
        // not the bucket color (pale fills would fail contrast).
        let labelColor = isAttempt ? Color.primary : ink

        HStack(spacing: 3) {
            if outcome == .flash {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(labelColor)
            } else if differentiateWithoutColor && outcome == .sent {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(labelColor)
            }

            Text(GradeDisplaySettings.shared.label(forStored: grade))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(labelColor)

            if count > 1 {
                Text("×\(count)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(labelColor.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background {
            ZStack {
                GeckoHoldShape()
                    .fill(color.opacity(isAttempt ? 0.16 : 1.0))
                if isAttempt {
                    DiagonalStripes(spacing: 5, lineWidth: 2)
                        .stroke(color.opacity(0.6), lineWidth: 2)
                        .clipShape(GeckoHoldShape())
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(GradeDisplaySettings.shared.label(forStored: grade)), \(outcome.label)\(count > 1 ? ", \(count) climbs" : "")")
    }
}

#if DEBUG
#Preview("Session strip + chips") {
    VStack(alignment: .leading, spacing: 20) {
        SessionStripView(
            climbs: PostModel.preview.climbSequence,
            durationMinutes: 95
        )
        HStack(spacing: 6) {
            ClimbChipView(grade: "V2", outcome: .flash)
            ClimbChipView(grade: "V3", outcome: .sent, count: 3)
            ClimbChipView(grade: "V4", outcome: .attempt, count: 2)
            ClimbChipView(grade: "V7", outcome: .sent)
        }
    }
    .padding()
}
#endif
