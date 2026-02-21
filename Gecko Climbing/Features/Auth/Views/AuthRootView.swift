import SwiftUI

struct AuthRootView: View {
    @State private var showSignUp = false

    var body: some View {
        if showSignUp {
            SignUpView(showSignUp: $showSignUp)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        } else {
            SignInView(showSignUp: $showSignUp)
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
        }
    }
}
