import SwiftUI

/// Gecko's signature silhouette — an asymmetric rounded rect whose opposed
/// big/small corners read as a climbing hold (a crimp) at any size. One shape
/// grammar shared by grade chips, top-send badges, and the stats hero so the
/// app is recognizable at a glance. Radii scale with height, so the same
/// shape works at 22pt chips and 120pt heroes.
struct GeckoHoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let h = rect.height
        return UnevenRoundedRectangle(
            topLeadingRadius: 0.46 * h,
            bottomLeadingRadius: 0.16 * h,
            bottomTrailingRadius: 0.46 * h,
            topTrailingRadius: 0.16 * h,
            style: .continuous
        )
        .path(in: rect)
    }
}

#if DEBUG
#Preview("Hold shape scales") {
    VStack(spacing: 20) {
        GeckoHoldShape()
            .fill(Color.gradeColor(for: 7))
            .frame(width: 150, height: 120)
            .overlay(
                Text("V7")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            )
        HStack(spacing: 8) {
            ForEach([1, 4, 6, 8, 10], id: \.self) { n in
                GeckoHoldShape()
                    .fill(Color.gradeColor(for: n))
                    .frame(width: 44, height: 26)
                    .overlay(
                        Text("V\(n)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(VGrade.textColor(for: n))
                    )
            }
        }
    }
    .padding()
}
#endif
