import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "figure.climbing")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Gecko Climbing")
                .font(.largeTitle)
                .bold()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
