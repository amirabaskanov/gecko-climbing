import SwiftUI
import Charts

struct GradePyramidView: View {
    let data: [GradeCount]

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Pyramid")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                Text("No sends recorded yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Count", appeared ? item.count : 0),
                        y: .value("Grade", item.grade)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.gradeColor(for: item.numeric).opacity(0.8),
                                Color.gradeColor(for: item.numeric)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(item.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let grade = value.as(String.self) {
                                Text(grade)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.gradeColor(for: VGrade.numeric(for: grade)))
                            }
                        }
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(max(data.count * 36, 120)))
                .padding(.horizontal)
                .onAppear {
                    withAnimation(.geckoSpring.delay(0.2)) {
                        appeared = true
                    }
                }
            }
        }
        .padding(.vertical)
        .cardStyle()
    }
}
