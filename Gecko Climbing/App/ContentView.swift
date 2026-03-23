import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            GeckoLogoView(size: 80, color: .geckoPrimary, showWordmark: true)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
