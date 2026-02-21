import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Binding var showSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var currentNonce = ""

    var body: some View {
        ZStack {
            Color.geckoBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Logo + tagline
                    VStack(spacing: 12) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 56))
                            .foregroundColor(Color.geckoGreen)
                        Text("Gecko Climbing")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Track every send.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)

                    // Social sign-in buttons (primary)
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = AppleSignInHelper.randomNonce()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AppleSignInHelper.sha256(nonce)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard
                                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                    let tokenData = credential.identityToken,
                                    let idToken = String(data: tokenData, encoding: .utf8)
                                else { return }
                                Task {
                                    await authViewModel.signInWithApple(
                                        idToken: idToken,
                                        rawNonce: currentNonce,
                                        fullName: credential.fullName
                                    )
                                }
                            case .failure:
                                break
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .disabled(authViewModel.isLoading)

                        Button {
                            Task { await authViewModel.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Google")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
                        }
                        .disabled(authViewModel.isLoading)
                    }
                    .padding(.horizontal, 24)

                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("or sign in with email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .layoutPriority(1)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .padding(.horizontal, 24)

                    // Email + Password fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                        Button {
                            Task { await authViewModel.signIn(email: email, password: password) }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.geckoGreen)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                    }
                    .padding(.horizontal, 24)

                    // Sign up link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        Button("Sign Up") {
                            withAnimation { showSignUp = true }
                        }
                        .foregroundColor(Color.geckoGreen)
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.bottom, 40)
                }
            }
        }
        .errorAlert(error: Binding(
            get: { authViewModel.error },
            set: { _ in authViewModel.clearError() }
        ))
    }
}
