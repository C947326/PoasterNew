//
//  XAPIClient.swift
//  Poaster
//

import Foundation

/// Errors from X API operations
enum XAPIError: LocalizedError {
    case unauthorized
    case rateLimited(resetAt: Date?)
    case invalidRequest(String)
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Not authenticated. Please sign in."
        case .rateLimited(let resetAt):
            if let date = resetAt {
                return "Rate limited. Try again at \(date.formatted())"
            }
            return "Rate limited. Please try again later."
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}

/// Response from posting a tweet
struct PostTweetResponse: Codable {
    let data: TweetData

    struct TweetData: Codable {
        let id: String
        let text: String
    }
}

/// User info response
struct UserResponse: Codable {
    let data: UserData

    struct UserData: Codable {
        let id: String
        let username: String
        let name: String
        let profileImageUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, username, name
            case profileImageUrl = "profile_image_url"
        }
    }
}

/// Client for X API v2 interactions
@Observable
final class XAPIClient {

    /// OAuth service for token management
    private let oauthService: OAuthService

    init(oauthService: OAuthService) {
        self.oauthService = oauthService
    }

    // MARK: - Tweet Operations

    /// Post a tweet
    /// - Parameters:
    ///   - text: The tweet text
    ///   - mediaIds: Optional array of media IDs to attach
    ///   - replyToTweetId: Optional tweet ID to reply to (for threading)
    /// - Returns: The posted tweet response
    func postTweet(
        text: String,
        mediaIds: [String]? = nil,
        replyToTweetId: String? = nil
    ) async throws -> PostTweetResponse {
        var body: [String: Any] = ["text": text]

        if let mediaIds = mediaIds, !mediaIds.isEmpty {
            body["media"] = ["media_ids": mediaIds]
        }

        if let replyTo = replyToTweetId {
            body["reply"] = ["in_reply_to_tweet_id": replyTo]
        }

        let data = try await request(
            endpoint: "/tweets",
            method: "POST",
            body: body
        )

        do {
            return try JSONDecoder().decode(PostTweetResponse.self, from: data)
        } catch {
            throw XAPIError.decodingError(error)
        }
    }

    // MARK: - User Operations

    /// Get the authenticated user's info
    func getCurrentUser() async throws -> XUser {
        let data = try await request(
            endpoint: "/users/me",
            method: "GET",
            queryItems: [URLQueryItem(name: "user.fields", value: "profile_image_url")]
        )

        do {
            let response = try JSONDecoder().decode(UserResponse.self, from: data)
            return XUser(
                id: response.data.id,
                username: response.data.username,
                name: response.data.name,
                profileImageURL: response.data.profileImageUrl
            )
        } catch {
            throw XAPIError.decodingError(error)
        }
    }

    // MARK: - Private Methods

    /// Make an authenticated request to the X API
    private func request(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: [String: Any]? = nil
    ) async throws -> Data {
        // Get valid access token
        let accessToken = try await getValidAccessToken()

        // Build URL
        var components = URLComponents(string: Constants.XAPI.baseURL + endpoint)!
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw XAPIError.invalidRequest("Invalid URL")
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // Execute request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw XAPIError.networkError(error)
        }

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XAPIError.unknown("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw XAPIError.unauthorized
        case 429:
            let resetAt = httpResponse.value(forHTTPHeaderField: "x-rate-limit-reset")
                .flatMap { Double($0) }
                .map { Date(timeIntervalSince1970: $0) }
            throw XAPIError.rateLimited(resetAt: resetAt)
        case 400...499:
            let message = String(data: data, encoding: .utf8) ?? "Client error"
            throw XAPIError.invalidRequest(message)
        default:
            throw XAPIError.serverError(httpResponse.statusCode)
        }
    }

    /// Get a valid access token, refreshing if needed
    private func getValidAccessToken() async throws -> String {
        // Check for valid cached token
        if let token = TokenStore.validAccessToken {
            return token
        }

        // Try to refresh
        let tokens = try await oauthService.refreshAccessToken()
        return tokens.accessToken
    }
}
