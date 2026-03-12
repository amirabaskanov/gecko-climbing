import SwiftUI

// Horizontal scrollable row of grade chips V0–V17
struct GradePickerView: View {
    @Binding var selectedGrade: String
    var onGradeSelected: ((String) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VGrade.all, id: \.self) { grade in
                    GradeChip(
                        grade: grade,
                        isSelected: selectedGrade == grade
                    ) {
                        selectedGrade = grade
                        onGradeSelected?(grade)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

struct GradeChip: View {
    let grade: String
    let isSelected: Bool
    let onTap: () -> Void

    private var numeric: Int { VGrade.numeric(for: grade) }
    private var color: Color { Color.gradeColor(for: numeric) }

    var body: some View {
        Button(action: onTap) {
            Text(grade)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? color : Color.surface)
                        .overlay(
                            isSelected ?
                                AnyView(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.25), Color.clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                )
                            : AnyView(EmptyView())
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : color.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(
                    color: isSelected ? color.opacity(0.4) : .clear,
                    radius: isSelected ? 6 : 0,
                    x: 0, y: isSelected ? 3 : 0
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.geckoSnappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// Standalone badge view for displaying a grade (non-interactive)
struct GradeBadge: View {
    let grade: String
    let isCompleted: Bool
    var size: GradeBadgeSize = .medium

    enum GradeBadgeSize {
        case small, medium, large
        var font: Font {
            switch self {
            case .small: return .system(size: 11, weight: .bold, design: .rounded)
            case .medium: return .system(size: 14, weight: .bold, design: .rounded)
            case .large: return .system(size: 22, weight: .black, design: .rounded)
            }
        }
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .medium: return EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
            case .large: return EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
            }
        }
    }

    private var numeric: Int { VGrade.numeric(for: grade) }
    private var color: Color { isCompleted ? Color.gradeColor(for: numeric) : Color(hex: "#9E9E9E") }

    var body: some View {
        Text(grade)
            .font(size.font)
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        size == .large && isCompleted
                            ? AnyShapeStyle(Color.gradeGradient(for: numeric))
                            : AnyShapeStyle(color)
                    )
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        GradePickerView(selectedGrade: .constant("V5"))
        HStack {
            GradeBadge(grade: "V3", isCompleted: true)
            GradeBadge(grade: "V5", isCompleted: true)
            GradeBadge(grade: "V7", isCompleted: false)
            GradeBadge(grade: "V10", isCompleted: true, size: .large)
        }
    }
    .padding()
}
