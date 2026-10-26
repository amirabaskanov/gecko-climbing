import SwiftUI

/// Section title for social surfaces: sentence case, bold rounded, with an
/// optional trailing action. Deliberately not the tracker's tracked-out
/// eyebrow; the crew tab reads like a social app, not a settings form.
struct SocialSectionHeader: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            if let detail {
                Text(detail)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.geckoSecondaryText)
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.geckoPrimary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Small hold-shaped grade tag used beside names and on avatar corners.
struct GradeTag: View {
    let gradeNumeric: Int
    var size: CGFloat = 22

    var body: some View {
        Text(GradeDisplaySettings.shared.label(for: gradeNumeric))
            .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(VGrade.textColor(for: gradeNumeric))
            .padding(.horizontal, size * 0.36)
            .frame(height: size)
            .background(GeckoHoldShape().fill(Color.gradeColor(for: gradeNumeric)))
            .accessibilityLabel("Top grade \(GradeDisplaySettings.shared.label(for: gradeNumeric))")
    }
}
