import SwiftUI

struct LoadingOverlay: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.75))
            )
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay {
            if isLoading {
                LoadingOverlay(message)
            }
        }
    }
}
