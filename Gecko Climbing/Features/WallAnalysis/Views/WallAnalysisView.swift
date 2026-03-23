import SwiftUI

struct WallAnalysisView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.geckoPrimary.opacity(0.12))
                        .frame(width: 140, height: 140)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.geckoPrimary)
                }

                VStack(spacing: 12) {
                    Text("Wall Analysis")
                        .font(.system(size: 28, weight: .black, design: .rounded))

                    Text("Coming in v2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.geckoOrange)
                        .clipShape(Capsule())

                    Text("Point your camera at a bouldering wall and Gecko will detect holds, identify routes, and help you plan your next problem.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "camera.fill", title: "Hold Detection", description: "Automatically spots climbing holds using on-device AI")
                    featureRow(icon: "paintpalette.fill", title: "Color Recognition", description: "Identifies route colors and difficulty indicators")
                    featureRow(icon: "chart.bar.fill", title: "Route Analysis", description: "Suggests sequences and beta for detected problems")
                }
                .padding(20)
                .cardStyle()
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(Color.geckoBackground)
            .navigationTitle("Analyze")
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.geckoPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WallAnalysisView()
}
