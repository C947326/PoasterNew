//
//  PKCEGenerator.swift
//  Poaster
//

import Foundation
import CryptoKit

/// Pure functions for generating PKCE (Proof Key for Code Exchange) values
/// Used for OAuth 2.0 authorization with X API
enum PKCEGenerator {

    /// Generate a cryptographically random code verifier
    /// - Returns: A URL-safe base64 encoded string of 43-128 characters
    static func generateCodeVerifier() -> String {
        // Generate 32 random bytes (will result in 43 base64 characters)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        // URL-safe base64 encoding without padding
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Generate the code challenge from a code verifier using S256
    /// - Parameter verifier: The code verifier string
    /// - Returns: The SHA256 hash of the verifier, URL-safe base64 encoded
    static func generateCodeChallenge(from verifier: String) -> String {
        // SHA256 hash of the verifier
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)

        // URL-safe base64 encoding without padding
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Generate a random state parameter for OAuth
    /// - Returns: A URL-safe random string for CSRF protection
    static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
