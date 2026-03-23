import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.gray.opacity(0.12))
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 42

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.12))
            .frame(width: size, height: size)
            .shimmer()
    }
}

struct SkeletonRect: View {
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.12))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Feed Card Skeleton

struct FeedCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: avatar + name
            HStack(spacing: 10) {
                SkeletonCircle(size: 42)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonLine(width: 120, height: 14)
                    SkeletonLine(width: 80, height: 10)
                }
                Spacer()
                SkeletonRect(height: 40, cornerRadius: 12)
                    .frame(width: 52)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Grade pills
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRect(height: 36, cornerRadius: 8)
                        .frame(width: 36)
                }
            }
            .padding(.horizontal, 16)

            // Footer
            HStack(spacing: 10) {
                SkeletonLine(width: 50, height: 28)
                SkeletonLine(width: 50, height: 28)
                Spacer()
                SkeletonLine(width: 70, height: 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .cardStyle()
    }
}

// MARK: - Session Row Skeleton

struct SessionRowSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonLine(width: 120, height: 14)
                    SkeletonLine(width: 80, height: 11)
                }
                Spacer()
                SkeletonRect(height: 28, cornerRadius: 14)
                    .frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            SkeletonRect(height: 6, cornerRadius: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                SkeletonLine(width: 50, height: 12)
                SkeletonLine(width: 65, height: 12)
                Spacer()
                SkeletonLine(width: 30, height: 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .cardStyle()
    }
}
