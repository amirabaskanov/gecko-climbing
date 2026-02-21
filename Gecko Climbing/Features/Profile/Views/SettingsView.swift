import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showSignOutConfirm = false

    var body: some View {
        Form {
            Section("Account") {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
                Label("Gecko Climbing", systemImage: "figure.climbing")
                    .foregroundColor(Color.geckoGreen)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign out of Gecko Climbing?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
