import SwiftUI

/// A climber's identity in one glance: how many climbs they've sent at each
/// grade, hardest at the top, in gym tape colors. Attempts extend the bar
/// as a hatched tail so projects are visible without reading as sends.
struct ClimberPyramidView: View {
    struct Bar: Identifiable, Equatable {
        let numeric: Int
        let sends: Int
        let attempts: Int
        var id: Int { numeric }
        var total: Int { sends + attempts }
    }

    let bars: [Bar]
    var maxRows: Int = 7

    private var visible: [Bar] {
        Array(bars.sorted { $0.numeric > $1.numeric }.prefix(maxRows))
    }

    private var scale: Int {
        max(1, visible.map(\.total).max() ?? 1)
    }

    var body: some View {
        VStack(spacing: 7) {
            ForEach(visible) { bar in
                row(bar)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func row(_ bar: Bar) -> some View {
        let color = Color.gradeColor(for: bar.numeric)
        return HStack(spacing: 10) {
            GradeTag(gradeNumeric: bar.numeric, size: 22)
                .frame(width: 44, alignment: .trailing)

            GeometryReader { geo in
                let unit = geo.size.width / CGFloat(scale)
                HStack(spacing: 2) {
                    if bar.sends > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color)
                            .frame(width: max(6, unit * CGFloat(bar.sends)))
                    }
                    if bar.attempts > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.16))
                            .overlay(
                                DiagonalStripes(spacing: 4, lineWidth: 1.5)
                                    .stroke(color.opacity(0.55), lineWidth: 1.5)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            )
                            .frame(width: max(6, unit * CGFloat(bar.attempts)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 14)

            Text("\(bar.sends)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var accessibilitySummary: String {
        visible.map { bar in
            let label = GradeDisplaySettings.shared.label(for: bar.numeric)
            var part = "\(label): \(bar.sends) sent"
            if bar.attempts > 0 { part += ", \(bar.attempts) attempted" }
            return part
        }
        .joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Grade pyramid") {
    ClimberPyramidView(bars: [
        .init(numeric: 2, sends: 14, attempts: 0),
        .init(numeric: 3, sends: 22, attempts: 2),
        .init(numeric: 4, sends: 11, attempts: 5),
        .init(numeric: 5, sends: 6, attempts: 4),
        .init(numeric: 6, sends: 1, attempts: 7),
        .init(numeric: 7, sends: 0, attempts: 3)
    ])
    .padding()
    .background(Color.geckoBackground)
}
#endif
