import SwiftUI

struct ClimbRowView: View {
    let climb: ClimbModel
    var index: Int = 0

    private var outcome: ClimbOutcome { climb.climbOutcome }
    private var gradeColor: Color { Color.gradeColor(for: climb.gradeNumeric) }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(gradeColor)
                .frame(width: 4)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                // Grade badge
                GradeBadge(grade: climb.grade, isCompleted: outcome.isCompleted)

                // Center content
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: outcome.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(outcome.color)
                        Text(outcome.label)
                            .font(.subheadline.weight(.semibold))
                        if outcome != .flash {
                            Text("· \(climb.attempts) \(climb.attempts == 1 ? "try" : "tries")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if outcome == .flash {
                        Text("First try!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !climb.notes.isEmpty {
                        Text(climb.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Timestamp
                Text(climb.loggedAt.timeFormatted)
                    .font(.caption2)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.geckoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
    }
}
