import SwiftUI

struct QuickAddClimbSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGrade: String = "V5"
    @State private var selectedOutcome: ClimbOutcome = .sent
    @State private var attempts: Int = 2
    @State private var logTrigger = 0

    let onAdd: (String, ClimbOutcome, Int) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("Log Climb")
                .font(.title3.weight(.black).width(.expanded))

            // Large grade badge
            GradeBadge(grade: selectedGrade, isCompleted: selectedOutcome.isCompleted, size: .large)
                .animation(.bouncy, value: selectedGrade)
                .animation(.bouncy, value: selectedOutcome)

            // Horizontal scrolling grade pills with snapping
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(VGrade.standard, id: \.self) { grade in
                        GradeChip(grade: grade, isSelected: selectedGrade == grade) {
                            withAnimation(.bouncy) { selectedGrade = grade }
                        }
                        .id(grade)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { Optional(selectedGrade) },
                set: { if let g = $0 { selectedGrade = g } }
            ))
            .scrollIndicators(.hidden)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedGrade)

            // 2x2 Outcome grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ClimbOutcome.allCases) { outcome in
                    OutcomeCard(
                        outcome: outcome,
                        isSelected: selectedOutcome == outcome
                    ) {
                        withAnimation(.bouncy) {
                            selectedOutcome = outcome
                            attempts = outcome.defaultAttempts
                        }

                        // Flash logs immediately
                        if outcome == .flash {
                            logTrigger += 1
                            onAdd(selectedGrade, .flash, 1)
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .sensoryFeedback(.impact(flexibility: .rigid), trigger: selectedOutcome)

            // Attempt stepper (hidden for flash)
            if selectedOutcome != .flash {
                HStack(spacing: 20) {
                    Button {
                        if attempts > selectedOutcome.minAttempts {
                            attempts -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(attempts > selectedOutcome.minAttempts ? selectedOutcome.color : .gray.opacity(0.3))
                    }
                    .disabled(attempts <= selectedOutcome.minAttempts)

                    VStack(spacing: 2) {
                        Text("\(attempts)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .contentTransition(.numericText())
                            .animation(.snappy, value: attempts)
                        Text(attempts == 1 ? "attempt" : "attempts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)

                    Button {
                        attempts += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(selectedOutcome.color)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            // Log button
            if selectedOutcome != .flash {
                Button {
                    logTrigger += 1
                    onAdd(selectedGrade, selectedOutcome, attempts)
                    dismiss()
                } label: {
                    Text("Log \(selectedOutcome.label) \(selectedGrade)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedOutcome.color)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .sensoryFeedback(.success, trigger: logTrigger)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Outcome Card
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
                    .fill(isSelected ? outcome.color : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.bouncy, value: isSelected)
        }
    }
}
