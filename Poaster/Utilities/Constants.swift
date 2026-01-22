//
//  Constants.swift
//  Poaster
//

import Foundation

/// Application-wide constants
enum Constants {

    // MARK: - X API Configuration

    enum XAPI {
        /// Your X API Client ID (from developer.x.com)
        /// Set this to your app's Client ID
        static let clientId = "VWkxOXBxNEJ4X2hGWU4zbnAxanE6MTpjaQ"

        /// Base URL for X API v2
        static let baseURL = "https://api.x.com/2"

        /// OAuth 2.0 authorization endpoint
        static let authorizationURL = "https://twitter.com/i/oauth2/authorize"

        /// OAuth 2.0 token endpoint
        static let tokenURL = "https://api.x.com/2/oauth2/token"

        /// Media upload endpoint (v1.1 still required for media)
        static let mediaUploadURL = "https://upload.twitter.com/1.1/media/upload.json"

        /// OAuth scopes required for posting
        static let scopes = [
            "tweet.read",
            "tweet.write",
            "users.read",
            "offline.access"
        ]

        /// Redirect URI for OAuth callback
        static let redirectURI = "poaster://oauth-callback"
    }

    // MARK: - Character Limits

    enum CharacterLimits {
        /// Standard character limit for free accounts
        static let standard = 280

        /// Premium character limit (X Premium subscribers)
        static let premium = 25000

        /// URL placeholder length (t.co shortening)
        static let urlLength = 23
    }

    // MARK: - Images

    enum Images {
        /// Maximum number of images per post
        static let maxCount = 4

        /// Maximum image file size in bytes (5MB)
        static let maxFileSize = 5 * 1024 * 1024

        /// Thumbnail size for list display
        static let thumbnailSize = CGSize(width: 100, height: 100)

        /// Maximum image dimension for upload
        static let maxDimension: CGFloat = 4096
    }

    // MARK: - Keychain Keys

    enum KeychainKeys {
        static let accessToken = "x_access_token"
        static let refreshToken = "x_refresh_token"
        static let tokenExpiry = "x_token_expiry"
        static let currentUser = "x_current_user"
    }

    // MARK: - UI

    enum UI {
        /// Minimum sidebar width
        static let sidebarMinWidth: CGFloat = 200

        /// Ideal sidebar width
        static let sidebarIdealWidth: CGFloat = 250

        /// Minimum detail view width
        static let detailMinWidth: CGFloat = 400
    }
}
