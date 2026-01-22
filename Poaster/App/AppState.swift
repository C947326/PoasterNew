//
//  AppState.swift
//  Poaster
//

import Foundation

/// Represents the authenticated X user
struct XUser: Equatable, Codable {
    let id: String
    let username: String
    let name: String
    let profileImageURL: String?
}

/// Global application state using the Observation framework
@Observable
final class AppState {
    /// The currently authenticated user
    var currentUser: XUser?

    /// Whether a post is currently being submitted
    var isPosting: Bool = false

    /// Error from the most recent posting attempt
    var postingError: Error?

    /// Error message for display
    var postingErrorMessage: String?

    // MARK: - Services

    /// OAuth service for authentication
    let oauthService: OAuthService

    /// API client for X API calls
    let apiClient: XAPIClient

    /// Media uploader for images
    let mediaUploader: MediaUploader

    /// Post composer for orchestrating posts
    let postComposer: PostComposer

    /// Whether the user is authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }

    init(currentUser: XUser? = nil) {
        self.currentUser = currentUser

        // Initialize services
        self.oauthService = OAuthService()
        self.apiClient = XAPIClient(oauthService: oauthService)
        self.mediaUploader = MediaUploader(oauthService: oauthService)
        self.postComposer = PostComposer(apiClient: apiClient, mediaUploader: mediaUploader)
    }

    /// Set the posting error and extract message
    func setPostingError(_ error: Error?) {
        postingError = error
        postingErrorMessage = error?.localizedDescription
    }

    /// Clear posting state after completion
    func clearPostingState() {
        isPosting = false
        postingError = nil
        postingErrorMessage = nil
    }
}
