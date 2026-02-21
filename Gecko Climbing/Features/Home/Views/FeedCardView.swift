import SwiftUI
import Charts

struct FeedCardView: View {
    let post: PostModel
    let onLike: () -> Void
    let onUserTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Button(action: onUserTap) {
                    AvatarView(url: post.userProfileImageURL, size: 42, name: post.userDisplayName)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 4) {
                        Text(post.gymName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(post.createdAt.relativeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // Top send badge
                if !post.topGrade.isEmpty {
                    VStack(spacing: 1) {
                        GradeBadge(grade: post.topGrade, isCompleted: true, size: .medium)
                        Text("top send")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .lineLimit(3)
            }

            // Mini grade pyramid
            if !post.gradeCounts.isEmpty {
                miniPyramid
            }

            // Stats row
            HStack(spacing: 16) {
                Label("\(post.totalClimbs) climbs", systemImage: "figure.climbing")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()

                // Like button
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(post.isLikedByCurrentUser ? .red : .secondary)
                        Text("\(post.likesCount)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.secondary)
                    Text("\(post.commentsCount)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // Compact grade distribution bars
    private var miniPyramid: some View {
        let sorted = post.gradeCounts
            .map { (grade: $0.key, count: $0.value, numeric: VGrade.numeric(for: $0.key)) }
            .sorted { $0.numeric < $1.numeric }
        let maxCount = sorted.map { $0.count }.max() ?? 1

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(sorted, id: \.grade) { item in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gradeColor(for: item.numeric))
                        .frame(width: 22, height: CGFloat(item.count) / CGFloat(maxCount) * 40 + 8)
                    Text(item.grade)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
