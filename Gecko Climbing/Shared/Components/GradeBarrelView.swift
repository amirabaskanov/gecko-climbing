import SwiftUI

struct GradeBarrelView: View {
    @Binding var selectedGrade: String
    var grades: [String] = VGrade.all

    @State private var scrollPosition: String?
    @State private var containerWidth: CGFloat = 0

    private let itemWidth: CGFloat = 110
    private let viewHeight: CGFloat = 200

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(grades, id: \.self) { grade in
                    gradeItem(grade)
                        .frame(width: itemWidth)
                        .id(grade)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .contentMargins(.horizontal, max((containerWidth - itemWidth) / 2, 0), for: .scrollContent)
        .scrollIndicators(.hidden)
        .frame(height: viewHeight)
        .clipShape(Rectangle())
        .sensoryFeedback(.selection, trigger: selectedGrade)
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        containerWidth = newWidth
                    }
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue {
                selectedGrade = newValue
            }
        }
        .onAppear {
            scrollPosition = selectedGrade
        }
    }

    private func gradeItem(_ grade: String) -> some View {
        let gradeColor = Color.gradeColor(for: grade)

        return Text(grade)
            .font(.system(size: 100, weight: .black, design: .rounded))
            .foregroundColor(gradeColor)
            .minimumScaleFactor(0.25)
            .lineLimit(1)
            .frame(width: itemWidth, height: viewHeight)
            .visualEffect { content, proxy in
                let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                let scrollViewWidth = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? containerWidth
                let center = scrollViewWidth / 2
                let itemCenter = frame.midX
                let distance = abs(center - itemCenter)
                let maxDistance: CGFloat = itemWidth * 2.5
                let progress = min(distance / maxDistance, 1.0)

                let scale = 1.0 - (progress * 0.6)
                let opacity = 1.0 - (progress * 0.7)

                return content
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            .background {
                if grade == selectedGrade {
                    RadialGradient(
                        colors: [gradeColor.opacity(0.25), gradeColor.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                    .frame(width: 160, height: 160)
                    .transition(.opacity)
                }
            }
    }
}
