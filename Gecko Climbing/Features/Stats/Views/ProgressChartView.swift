import SwiftUI
import Charts

struct ProgressChartView: View {
    let data: [SessionProgress]

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Progress")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                Text("Log more sessions to see your progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(data) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Grade", item.highestGradeNumeric)
                    )
                    .foregroundStyle(Color.geckoGreen)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Grade", item.highestGradeNumeric)
                    )
                    .foregroundStyle(Color.gradeColor(for: item.highestGradeNumeric))
                    .symbolSize(appeared ? 60 : 0)
                }
                .chartYAxis {
                    AxisMarks(values: .stride(by: 1)) { value in
                        if let numeric = value.as(Int.self), numeric >= 0 {
                            AxisValueLabel {
                                Text(VGrade.label(for: numeric))
                                    .font(.caption2)
                                    .foregroundColor(Color.gradeColor(for: numeric))
                            }
                            AxisGridLine()
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.dayMonthFormatted)
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
                .onAppear {
                    withAnimation(.geckoSpring.delay(0.4)) {
                        appeared = true
                    }
                }
            }
        }
        .padding(.vertical)
        .cardStyle()
    }
}
