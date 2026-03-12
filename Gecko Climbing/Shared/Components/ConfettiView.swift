import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool
    var colors: [Color] = [
        .geckoGreen, .geckoFlashGold, .geckoProjectBlue,
        .geckoOrange, .geckoGreenLight, Color(hex: "#FFC107"),
        Color(hex: "#9C27B0"), Color(hex: "#FF9800")
    ]
    var particleCount: Int = 60
    var duration: Double = 3.0

    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard let start = startTime else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                let progress = min(elapsed / duration, 1.0)

                for particle in particles {
                    let age = elapsed - particle.delay
                    guard age > 0 else { continue }

                    let x = particle.startX * size.width + sin(age * particle.wobbleSpeed) * particle.wobbleAmount
                    let y = particle.startY + age * particle.fallSpeed * size.height * 0.3 + 0.5 * 120 * age * age
                    let rotation = Angle.degrees(age * particle.rotationSpeed)
                    let opacity = progress > 0.7 ? max(0, 1.0 - (progress - 0.7) / 0.3) : 1.0

                    guard y < size.height + 20 else { continue }

                    context.opacity = opacity * particle.opacity
                    context.translateBy(x: x, y: y)
                    context.rotate(by: rotation)

                    let rect = CGRect(
                        x: -particle.size / 2,
                        y: -particle.size / 2,
                        width: particle.size,
                        height: particle.isCircle ? particle.size : particle.size * 0.6
                    )

                    if particle.isCircle {
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(particle.color)
                        )
                    } else {
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1),
                            with: .color(particle.color)
                        )
                    }

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                startConfetti()
            }
        }
        .onAppear {
            if isActive {
                startConfetti()
            }
        }
    }

    private func startConfetti() {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                startX: CGFloat.random(in: 0...1),
                startY: CGFloat.random(in: -40...(-10)),
                fallSpeed: CGFloat.random(in: 0.2...0.5),
                wobbleSpeed: Double.random(in: 2...6),
                wobbleAmount: CGFloat.random(in: 15...40),
                rotationSpeed: Double.random(in: 60...300),
                size: CGFloat.random(in: 5...10),
                color: colors.randomElement() ?? .geckoGreen,
                isCircle: Bool.random(),
                opacity: Double.random(in: 0.7...1.0),
                delay: Double.random(in: 0...0.5)
            )
        }
        startTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isActive = false
        }
    }
}

private struct ConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let fallSpeed: CGFloat
    let wobbleSpeed: Double
    let wobbleAmount: CGFloat
    let rotationSpeed: Double
    let size: CGFloat
    let color: Color
    let isCircle: Bool
    let opacity: Double
    let delay: Double
}
