import SwiftUI

/// Counts up from 0 to `target` with a numeric content transition. Uses
/// `.task(id:)` so the animation cancels cleanly if the view goes away mid-count.
struct AnimatedCounter: View {
    let target: Int
    var duration: Double = 0.8
    var delay: Double = 0
    var font: Font = .system(size: 28, weight: .black, design: .rounded)
    var color: Color = .primary

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .task(id: target) {
                await runCount()
            }
    }

    private func runCount() async {
        displayValue = 0
        guard target > 0 else { return }
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
        }
        let steps = min(target, 20)
        let stepDuration = duration / Double(steps)
        for i in 1...steps {
            if Task.isCancelled { return }
            let next = Int(Double(target) * Double(i) / Double(steps))
            withAnimation(.geckoSnappy) {
                displayValue = next
            }
            try? await Task.sleep(for: .seconds(stepDuration))
        }
    }
}

/// Pops a label into view once with a bouncy scale animation.
struct AnimatedCounterText: View {
    let value: String
    var delay: Double = 0
    var font: Font = .system(size: 18, weight: .black, design: .rounded)
    var color: Color = .primary

    @State private var appeared = false

    var body: some View {
        Text(value)
            .font(font)
            .foregroundStyle(color)
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1 : 0)
            .task(id: value) {
                appeared = false
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                    if Task.isCancelled { return }
                }
                withAnimation(.geckoBounce) {
                    appeared = true
                }
            }
    }
}
