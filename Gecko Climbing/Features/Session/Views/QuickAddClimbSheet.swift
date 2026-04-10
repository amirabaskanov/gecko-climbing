import SwiftUI

struct QuickAddClimbSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGrade: String = "V5"
    @State private var selectedOutcome: ClimbOutcome = .sent
    @State private var attempts: Int = 2
    @State private var showAttemptSelector = false
    @State private var logTrigger = 0

    let onAdd: (String, ClimbOutcome, Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Grade barrel
                    GradeBarrelView(selectedGrade: $selectedGrade)

                    // Outcome buttons (same style as NewSessionView)
                    HStack(spacing: 10) {
                        outcomeButton(.flash, icon: "bolt.fill", label: "FLASH", subtitle: "1 try")
                        outcomeButton(.sent, icon: "checkmark", label: "SENT", subtitle: nil)
                        outcomeButton(.attempt, icon: "arrow.trianglehead.counterclockwise", label: "ATTEMPT", subtitle: nil)
                    }
                    .padding(.horizontal, 16)

                    // Attempt selector (for sent/attempt)
                    if showAttemptSelector {
                        AttemptBubbleSelector(
                            accentColor: selectedOutcome.color,
                            minimumAttempts: selectedOutcome == .attempt ? 1 : 2
                        ) { count in
                            withAnimation(.geckoSnappy) {
                                showAttemptSelector = false
                            }
                            attempts = count
                            logTrigger += 1
                            onAdd(selectedGrade, selectedOutcome, count)
                            dismiss()
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 4)
            }
            .background(Color.geckoBackground)
            .navigationTitle("Log Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .sensoryFeedback(.success, trigger: logTrigger)
            .animation(.geckoSnappy, value: showAttemptSelector)
        }
    }

    private func outcomeButton(_ outcome: ClimbOutcome, icon: String, label: String, subtitle: String?) -> some View {
        Button {
            handleOutcomeTap(outcome)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(outcome.color.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .foregroundStyle(outcome.color)
            .background(outcome.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(outcome.color.opacity(outcome == .flash ? 0.6 : 0.3), lineWidth: outcome == .flash ? 2 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .bouncePress()
        .sensoryFeedback(.impact(flexibility: outcome == .flash ? .rigid : .soft,
                                  intensity: outcome == .flash ? 0.9 : 0.5),
                          trigger: selectedOutcome == outcome)
    }

    private func handleOutcomeTap(_ outcome: ClimbOutcome) {
        switch outcome {
        case .flash:
            logTrigger += 1
            onAdd(selectedGrade, .flash, 1)
            dismiss()
        case .sent, .attempt:
            withAnimation(.geckoSnappy) {
                selectedOutcome = outcome
                showAttemptSelector = true
            }
        }
    }
}

// MARK: - Outcome Card (kept for backwards compatibility)
struct OutcomeCard: View {
    let outcome: ClimbOutcome
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: outcome.icon)
                    .font(.title2)
                Text(outcome.label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(outcome.color) : AnyShapeStyle(Color.geckoInputBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.geckoDivider, lineWidth: isSelected ? 0 : 1)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.bouncy, value: isSelected)
        }
    }
}
