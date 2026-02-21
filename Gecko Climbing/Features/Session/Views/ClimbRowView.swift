import SwiftUI

struct ClimbRowView: View {
    let climb: ClimbModel

    private var outcome: ClimbOutcome { climb.climbOutcome }

    var body: some View {
        HStack(spacing: 12) {
            GradeBadge(grade: climb.grade, isCompleted: outcome.isCompleted)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: outcome.icon)
                        .font(.caption)
                        .foregroundColor(outcome.color)
                    Text(outcome.label)
                        .font(.subheadline.weight(.semibold))
                    if outcome != .flash {
                        Text("· \(climb.attempts) \(climb.attempts == 1 ? "try" : "tries")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if !climb.notes.isEmpty {
                    Text(climb.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: outcome.icon)
                .foregroundColor(outcome.color)
                .font(.title3)

            Text(climb.loggedAt.timeFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
