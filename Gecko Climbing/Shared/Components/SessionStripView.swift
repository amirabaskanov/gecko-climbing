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

// MARK: - Session Chips

/// The feed card's climbs display: grouped hold-shaped chips with grade
/// labels, capped so a 25-climb session never dominates the card. Identical
/// consecutive climbs collapse into one chip with a multiplier, attempts get
/// the hatch texture, and anything past the cap sits behind a "+N more"
/// expander that unfolds in place.
struct SessionChipsView: View {
    let climbs: [PostClimb]
    let groups: [PostClimbGroup]
    var durationMinutes: Int?
    /// The feed card renders its own headline numbers above the chips, so
    /// it turns the inline stat line off.
    var showsStats: Bool = true
    /// Post detail is where the full story lives, so it starts expanded.
    var startsExpanded: Bool = false

    @State private var expanded = false
    @State private var didApplyInitialState = false

    /// Collapsed cap. Seven grouped chips is at most two rows in a feed card.
    private let maxGroups = 7

    private var visibleGroups: [PostClimbGroup] {
        expanded ? groups : Array(groups.prefix(maxGroups))
    }

    private var hiddenClimbCount: Int {
        groups.dropFirst(maxGroups).reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6, rowSpacing: 6) {
                ForEach(visibleGroups) { group in
                    ClimbChipView(grade: group.grade, outcome: group.outcome, count: group.count)
                }
                if !expanded && hiddenClimbCount > 0 {
                    Button {
                        withAnimation(.geckoSpring) { expanded = true }
                    } label: {
                        moreChip
                    }
                    .buttonStyle(.borderless)
                }
            }
            if showsStats {
                statLine
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAction(named: "Show all climbs") { expanded = true }
        .onAppear {
            guard !didApplyInitialState else { return }
            didApplyInitialState = true
            expanded = startsExpanded
        }
    }

    private var moreChip: some View {
        Text("+\(hiddenClimbCount) more")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.geckoSecondaryText)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(GeckoHoldShape().fill(Color.geckoInputBackground))
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
        Text("\u{B7}")
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
#Preview("Session chips") {
    VStack(alignment: .leading, spacing: 20) {
        SessionChipsView(
            climbs: PostModel.preview.climbSequence,
            groups: PostModel.preview.groupedChips(),
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
