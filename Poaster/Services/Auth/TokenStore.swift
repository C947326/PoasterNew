//
//  TokenStore.swift
//  Poaster
//

import Foundation

/// Raw token response from X API (used for decoding)
struct XAPITokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }

    /// Convert to OAuthTokens with timestamp
    func toOAuthTokens() -> OAuthTokens {
        OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenType: tokenType,
            scope: scope,
            obtainedAt: Date()
        )
    }
}

/// OAuth tokens with metadata for storage
struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?

    /// When the token was obtained (for expiry calculation)
    let obtainedAt: Date

    /// Check if the access token is expired (with 5 minute buffer)
    var isExpired: Bool {
        let expiryDate = obtainedAt.addingTimeInterval(TimeInterval(expiresIn - 300))
        return Date() >= expiryDate
    }
}

/// Secure storage for OAuth tokens using Keychain
enum TokenStore {

    private static let tokensKey = "oauth_tokens"

    /// Save OAuth tokens to Keychain
    static func save(_ tokens: OAuthTokens) throws {
        try KeychainHelper.save(tokens, for: tokensKey)
    }

    /// Load OAuth tokens from Keychain
    static func load() throws -> OAuthTokens {
        try KeychainHelper.load(for: tokensKey)
    }

    /// Delete OAuth tokens from Keychain
    static func delete() throws {
        try KeychainHelper.delete(for: tokensKey)
    }

    /// Check if tokens exist
    static var hasTokens: Bool {
        KeychainHelper.exists(for: tokensKey)
    }

    /// Get the current access token if available and not expired
    static var validAccessToken: String? {
        guard let tokens = try? load(), !tokens.isExpired else {
            return nil
        }
        return tokens.accessToken
    }
}
