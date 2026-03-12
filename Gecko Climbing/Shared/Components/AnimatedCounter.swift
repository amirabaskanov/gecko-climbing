import SwiftUI

struct AnimatedCounter: View {
    let target: Int
    var duration: Double = 0.8
    var delay: Double = 0
    var font: Font = .system(size: 28, weight: .black, design: .rounded)
    var color: Color = .white

    @State private var displayValue: Int = 0
    @State private var isAnimating = false

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    animateCount()
                }
            }
    }

    private func animateCount() {
        guard target > 0 else {
            displayValue = target
            return
        }
        let steps = min(target, 20)
        let interval = duration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.geckoSnappy) {
                    displayValue = Int(Double(target) * Double(i) / Double(steps))
                }
            }
        }
    }
}

struct AnimatedCounterText: View {
    let value: String
    var delay: Double = 0
    var font: Font = .system(size: 18, weight: .black, design: .rounded)
    var color: Color = .white

    @State private var appeared = false

    var body: some View {
        Text(value)
            .font(font)
            .foregroundColor(color)
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.geckoBounce.delay(delay)) {
                    appeared = true
                }
            }
    }
}
