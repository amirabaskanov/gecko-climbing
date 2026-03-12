import SwiftUI

struct ClimbPillView: View {
    let climb: ClimbModel
    var onDelete: (() -> Void)?

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    private var outcome: ClimbOutcome { climb.climbOutcome }
    private var gradeColor: Color { Color.gradeColor(for: climb.gradeNumeric) }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            if showDelete {
                Button {
                    withAnimation(.geckoSpring) { onDelete?() }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.red, in: Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Pill content
            HStack(spacing: 5) {
                Text(climb.grade)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(gradeColor)

                Image(systemName: outcome.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(outcome.color)

                if outcome != .flash && climb.attempts > 1 {
                    Text("\u{00D7}\(climb.attempts)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
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
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.geckoSnappy) {
                            if value.translation.width < -50 {
                                showDelete = true
                                offset = -40
                            } else {
                                showDelete = false
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if showDelete {
                    withAnimation(.geckoSnappy) {
                        showDelete = false
                        offset = 0
                    }
                }
            }
        }
    }
}
