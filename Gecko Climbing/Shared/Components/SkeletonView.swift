import SwiftUI

// MARK: - Skeleton Palette

private extension Color {
    /// Dull base fill for skeleton bones. Slightly darker than the card in light mode,
    /// slightly lighter than the card in dark mode, so bones read in both.
    static let skeletonBase = Color.dynamic(light: "#E8E4DD", dark: "#2B3732")
    /// Highlight that sweeps across during the shimmer animation.
    static let skeletonHighlight = Color.dynamic(light: "#F7F4EE", dark: "#3C4A44")
}

// MARK: - Shimmer Effect

/// Sweeping highlight used on top of skeleton placeholders. Driven by
/// `TimelineView(.animation)` so the shimmer pauses automatically when the
/// view leaves the hierarchy or is off-screen — unlike a
/// `withAnimation(.repeatForever)` loop, which is decoupled from view/task
/// lifetime and keeps burning CPU until the view itself is torn down.
struct ShimmerModifier: ViewModifier {
    /// Seconds per shimmer sweep.
    private let period: Double = 1.2

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // Phase ramps from -1 to +1 over `period` seconds, then wraps.
                    let normalized = (t.truncatingRemainder(dividingBy: period)) / period
                    let phase = CGFloat(normalized * 2 - 1)

                    LinearGradient(
                        colors: [.clear, Color.skeletonHighlight.opacity(0.9), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * 200)
                    .mask(content)
                }
            )
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
            .fill(Color.skeletonBase)
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 42

    var body: some View {
        Circle()
            .fill(Color.skeletonBase)
            .frame(width: size, height: size)
            .shimmer()
    }
}

struct SkeletonRect: View {
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.skeletonBase)
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
