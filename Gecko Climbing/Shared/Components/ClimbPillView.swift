import SwiftUI

struct ClimbPillView: View {
    let climb: ClimbModel

    private var outcome: ClimbOutcome { climb.climbOutcome }
    private var gradeColor: Color { Color.gradeColor(for: climb.gradeNumeric) }

    var body: some View {
        HStack(spacing: 5) {
            Text(climb.grade)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(gradeColor)

            Image(systemName: outcome.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(outcome.color)

            if outcome != .flash && climb.attempts > 1 {
                Text("\u{00D7}\(climb.attempts)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(gradeColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(gradeColor.opacity(0.2), lineWidth: 1)
        )
    }
}
