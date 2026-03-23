import SwiftUI

struct GradeBarrelView: View {
    @Binding var selectedGrade: String
    var grades: [String] = VGrade.all

    @State private var scrollPosition: String?
    @State private var containerWidth: CGFloat = 0
    @State private var showHint = false

    /// Responsive item width: roughly 1/3 of container, clamped to reasonable range
    private var itemWidth: CGFloat {
        let third = containerWidth / 3
        return min(max(third, 90), 130)
    }
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
                Color.clear.onAppear {
                    containerWidth = geo.size.width
                    // Set scroll position after layout is measured
                    DispatchQueue.main.async {
                        scrollPosition = selectedGrade
                    }
                }
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
            // Subtle bounce hint after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showHint = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showHint = false
                    }
                }
            }
        }
        // Hint arrows on first appearance
        .overlay(alignment: .leading) {
            if showHint {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .trailing) {
            if showHint {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.trailing, 8)
                    .transition(.opacity)
            }
        }
    }

    private func gradeItem(_ grade: String) -> some View {
        let gradeColor = Color.gradeColor(for: grade)
        let currentItemWidth = itemWidth

        return Text(grade)
            .font(.system(size: 100, weight: .black, design: .rounded))
            .foregroundStyle(gradeColor)
            .minimumScaleFactor(0.25)
            .lineLimit(1)
            .frame(width: currentItemWidth, height: viewHeight)
            .visualEffect { content, proxy in
                let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                let scrollViewWidth = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 400
                let center = scrollViewWidth / 2
                let itemCenter = frame.midX
                let distance = abs(center - itemCenter)
                let maxDistance: CGFloat = currentItemWidth * 2.5
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
