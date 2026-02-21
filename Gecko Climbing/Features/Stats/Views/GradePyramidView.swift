import SwiftUI
import Charts

struct GradePyramidView: View {
    let data: [GradeCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Pyramid")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                Text("No sends recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Grade", item.grade)
                    )
                    .foregroundStyle(Color.gradeColor(for: item.numeric))
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(item.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let grade = value.as(String.self) {
                                Text(grade)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(Color.gradeColor(for: VGrade.numeric(for: grade)))
                            }
                        }
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(max(data.count * 36, 120)))
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .cardStyle()
    }
}
