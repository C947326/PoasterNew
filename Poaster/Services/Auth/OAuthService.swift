//
//  OAuthService.swift
//  Poaster
//

import Foundation
import AuthenticationServices

/// Errors that can occur during OAuth flow
enum OAuthError: LocalizedError {
    case invalidClientId
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case invalidResponse
    case stateMismatch
    case noRefreshToken
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidClientId:
            return "Invalid or missing Client ID"
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .stateMismatch:
            return "State mismatch - possible CSRF attack"
        case .noRefreshToken:
            return "No refresh token available"
        case .userCancelled:
            return "User cancelled authentication"
        }
    }
}

/// Service for handling OAuth 2.0 PKCE authentication with X API
@Observable
final class OAuthService: NSObject {

    /// Whether authentication is in progress
    var isAuthenticating = false

    /// Current authentication error
    var authError: OAuthError?

    /// The X API Client ID from Constants
    private var clientId: String { Constants.XAPI.clientId }

    // MARK: - Private State

    private var codeVerifier: String?
    private var expectedState: String?
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Public API

    /// Start the OAuth authorization flow
    /// - Parameter presentationContext: The context for presenting the auth UI
    func startAuthorization(presentationContext: ASWebAuthenticationPresentationContextProviding) async throws {
        guard clientId != "YOUR_CLIENT_ID_HERE" && !clientId.isEmpty else {
            throw OAuthError.invalidClientId
        }

        await MainActor.run {
            isAuthenticating = true
            authError = nil
        }

        // Ensure we always reset isAuthenticating
        defer {
            Task { @MainActor in
                isAuthenticating = false
            }
        }

        // Generate PKCE values
        let verifier = PKCEGenerator.generateCodeVerifier()
        let challenge = PKCEGenerator.generateCodeChallenge(from: verifier)
        let state = PKCEGenerator.generateState()

        codeVerifier = verifier
        expectedState = state

        // Build authorization URL
        var components = URLComponents(string: Constants.XAPI.authorizationURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: Constants.XAPI.redirectURI),
            URLQueryItem(name: "scope", value: Constants.XAPI.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw OAuthError.authorizationFailed("Failed to construct authorization URL")
        }

        print("[OAuth] Starting authorization...")

        // Start web authentication session
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "poaster"
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        continuation.resume(throwing: OAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: OAuthError.authorizationFailed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.invalidResponse)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session
            session.start()
        }

        print("[OAuth] Got callback URL: \(callbackURL)")

        // Parse the callback URL
        let tokens = try await handleCallback(callbackURL)

        print("[OAuth] Got tokens, saving...")

        // Save tokens
        try TokenStore.save(tokens)

        print("[OAuth] Authorization complete!")
    }

    /// Refresh the access token using the refresh token
    func refreshAccessToken() async throws -> OAuthTokens {
        guard let currentTokens = try? TokenStore.load(),
              let refreshToken = currentTokens.refreshToken else {
            throw OAuthError.noRefreshToken
        }

        var request = URLRequest(url: URL(string: Constants.XAPI.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
        .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed("Refresh failed")
        }

        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(XAPITokenResponse.self, from: data)

        // Convert to OAuthTokens, preserving refresh token if not returned
        let tokens = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresIn: tokenResponse.expiresIn,
            tokenType: tokenResponse.tokenType,
            scope: tokenResponse.scope,
            obtainedAt: Date()
        )

        try TokenStore.save(tokens)
        return tokens
    }

    /// Sign out and clear tokens
    func signOut() throws {
        try TokenStore.delete()
    }

    // MARK: - Private Methods

    /// Handle the OAuth callback URL and exchange code for tokens
    private func handleCallback(_ url: URL) async throws -> OAuthTokens {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw OAuthError.invalidResponse
        }

        // Check for error
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            throw OAuthError.authorizationFailed(description)
        }

        // Verify state
        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            throw OAuthError.stateMismatch
        }

        // Get authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.invalidResponse
        }

        // Exchange code for tokens
        return try await exchangeCodeForTokens(code)
    }

    /// Exchange authorization code for access tokens
    private func exchangeCodeForTokens(_ code: String) async throws -> OAuthTokens {
        guard let verifier = codeVerifier else {
            throw OAuthError.invalidResponse
        }

        print("[OAuth] Exchanging code for tokens...")

        var request = URLRequest(url: URL(string: Constants.XAPI.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Constants.XAPI.redirectURI,
            "client_id": clientId,
            "code_verifier": verifier
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
        .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        print("[OAuth] Making token request to: \(Constants.XAPI.tokenURL)")

        let (data, response) = try await URLSession.shared.data(for: request)

        print("[OAuth] Got response")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenExchangeFailed("Invalid response type")
        }

        print("[OAuth] Status code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[OAuth] Error body: \(errorBody)")
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(XAPITokenResponse.self, from: data)
        let tokens = tokenResponse.toOAuthTokens()

        print("[OAuth] Token exchange successful!")
        return tokens
    }
}
