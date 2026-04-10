import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Binding var showSignUp: Bool

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var currentNonce = ""

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !displayName.isEmpty && !authViewModel.isLoading
    }

    var body: some View {
        ZStack {
            Color.geckoBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        GeckoLogoView(size: 44, color: .geckoPrimary)

                        Text("Create Account")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text("Join the climbing community")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 50)

                    // Social sign-up buttons
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signUp) { request in
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
                                else {
                                    authViewModel.handleAppleTokenMissing()
                                    return
                                }
                                let nonce = currentNonce
                                Task {
                                    await authViewModel.signInWithApple(
                                        idToken: idToken,
                                        rawNonce: nonce,
                                        fullName: credential.fullName
                                    )
                                }
                            case .failure(let error):
                                authViewModel.handleAppleAuthorizationFailure(error)
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
                            .background(Color.geckoCard)
                            .foregroundStyle(.primary)
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
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("or sign up with email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.secondary.opacity(0.3))
                    }
                    .padding(.horizontal, 24)

                    // Form — 3 fields
                    VStack(spacing: 14) {
                        inputField("Your Name", text: $displayName, icon: "person.fill")
                        inputField("Email", text: $email, icon: "envelope.fill")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        secureField("Password", text: $password)

                        Button {
                            Task { await authViewModel.signUp(email: email, password: password, displayName: displayName) }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSubmit ? Color.geckoPrimary : Color.geckoSecondaryText.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSubmit)
                    }
                    .padding(.horizontal, 24)

                    // Sign in link
                    HStack {
                        Text("Already have an account?")
                            .foregroundStyle(.secondary)
                        Button("Sign In") {
                            withAnimation { showSignUp = false }
                        }
                        .foregroundStyle(Color.geckoPrimary)
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

    private func inputField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.geckoPrimary)
                .frame(width: 24)
            TextField(placeholder, text: text)
        }
        .padding()
        .background(Color.geckoInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.geckoPrimary)
                .frame(width: 24)
            SecureField(placeholder, text: text)
        }
        .padding()
        .background(Color.geckoInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
