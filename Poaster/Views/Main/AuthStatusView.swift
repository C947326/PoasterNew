//
//  AuthStatusView.swift
//  Poaster
//

import SwiftUI
import AuthenticationServices

/// Toolbar view showing authentication status with sign in/out functionality
struct AuthStatusView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSignOutConfirmation = false
    @State private var authError: String?

    var body: some View {
        Group {
            if appState.isAuthenticated {
                authenticatedView
            } else {
                signInButton
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Authentication Error", isPresented: .init(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("OK") { authError = nil }
        } message: {
            Text(authError ?? "Unknown error")
        }
    }

    /// View shown when authenticated
    private var authenticatedView: some View {
        Menu {
            if let user = appState.currentUser {
                Text("@\(user.username)")
                Divider()
            }
            Button("Sign Out", role: .destructive) {
                showingSignOutConfirmation = true
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                if let user = appState.currentUser {
                    Text(user.name)
                        .lineLimit(1)
                } else {
                    Text("Signed In")
                }
            }
        }
    }

    /// Sign in button
    private var signInButton: some View {
        Button(action: signIn) {
            if appState.oauthService.isAuthenticating {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Label("Sign in to X", systemImage: "person.badge.key")
            }
        }
        .disabled(appState.oauthService.isAuthenticating)
    }

    /// Start the OAuth sign in flow
    private func signIn() {
        Task {
            do {
                let context = AuthPresentationContext()
                try await appState.oauthService.startAuthorization(presentationContext: context)

                // Fetch user info after successful auth
                let user = try await appState.apiClient.getCurrentUser()

                await MainActor.run {
                    appState.currentUser = user
                }
            } catch let error as OAuthError {
                if case .userCancelled = error {
                    // User cancelled, don't show error
                    return
                }
                await MainActor.run {
                    authError = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                }
            }
        }
    }

    /// Sign out
    private func signOut() {
        do {
            try appState.oauthService.signOut()
            appState.currentUser = nil
        } catch {
            authError = error.localizedDescription
        }
    }
}

/// Provides a window for ASWebAuthenticationSession
final class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

#Preview {
    AuthStatusView()
        .environment(AppState())
        .padding()
}
