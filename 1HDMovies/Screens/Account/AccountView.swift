import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthenticationService.shared
    @State private var syncService = FirebaseSyncService.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        if auth.isSignedIn {
            signedInSection
        } else {
            signInSection
        }
    }

    private var signInSection: some View {
        Section {
            Button {
                Task {
                    do {
                        try await auth.signInWithGoogle()
                        await syncAfterSignIn()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.blue, .blue.opacity(0.1))
                    Text("Sign in with Google")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.black)
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.gray.opacity(0.15))

            SignInWithAppleButton(.signIn) { request in
                let hashedNonce = auth.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                Task {
                    do {
                        let authorization = try result.get()
                        try await auth.handleAppleSignIn(authorization: authorization)
                        await syncAfterSignIn()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 44)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.gray.opacity(0.15))
        } header: {
            Text("Account")
        } footer: {
            Text("Sign in to back up your favorites to the cloud")
        }
    }

    private var signedInSection: some View {
        Section("Account") {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = auth.displayName, !name.isEmpty {
                        Text(name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    if let email = auth.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .listRowBackground(Color.gray.opacity(0.15))

            Button {
                Task {
                    await FirebaseSyncService.shared.syncAll()
                }
            } label: {
                HStack {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.white)
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView()
                            .tint(.white)
                    } else if let date = syncService.lastSyncDate {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(syncService.isSyncing)
            .listRowBackground(Color.gray.opacity(0.15))

            Button {
                showSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.gray.opacity(0.15))
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    try? AuthenticationService.shared.signOut()
                }
            } message: {
                Text("Your favorites will remain on this device but will no longer sync to the cloud.")
            }
        }
    }

    private func syncAfterSignIn() async {
        await syncService.syncAll()
    }
}
