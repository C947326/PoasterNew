//
//  MediaUploader.swift
//  Poaster
//

import Foundation

/// Errors from media upload operations
enum MediaUploadError: LocalizedError {
    case imageTooLarge
    case uploadFailed(String)
    case processingFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .imageTooLarge:
            return "Image exceeds maximum file size"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .timeout:
            return "Upload timed out"
        }
    }
}

/// Response from media upload initialization
private struct MediaInitResponse: Codable {
    let mediaIdString: String

    enum CodingKeys: String, CodingKey {
        case mediaIdString = "media_id_string"
    }
}

/// Response from media upload finalize
private struct MediaFinalizeResponse: Codable {
    let mediaIdString: String
    let processingInfo: ProcessingInfo?

    struct ProcessingInfo: Codable {
        let state: String
        let checkAfterSecs: Int?

        enum CodingKeys: String, CodingKey {
            case state
            case checkAfterSecs = "check_after_secs"
        }
    }

    enum CodingKeys: String, CodingKey {
        case mediaIdString = "media_id_string"
        case processingInfo = "processing_info"
    }
}

/// Service for uploading media to X
/// Uses the chunked upload process for reliability
@Observable
final class MediaUploader {

    private let oauthService: OAuthService

    init(oauthService: OAuthService) {
        self.oauthService = oauthService
    }

    /// Upload an image and return its media ID
    /// - Parameter imageData: JPEG image data to upload
    /// - Returns: The media ID string
    func uploadImage(_ imageData: Data) async throws -> String {
        // Check size limit
        guard imageData.count <= Constants.Images.maxFileSize else {
            throw MediaUploadError.imageTooLarge
        }

        // Get access token
        let accessToken = try await getValidAccessToken()

        // Step 1: INIT
        let mediaId = try await initUpload(
            totalBytes: imageData.count,
            accessToken: accessToken
        )

        // Step 2: APPEND (single chunk for images under 5MB)
        try await appendChunk(
            mediaId: mediaId,
            data: imageData,
            segmentIndex: 0,
            accessToken: accessToken
        )

        // Step 3: FINALIZE
        let finalResponse = try await finalizeUpload(
            mediaId: mediaId,
            accessToken: accessToken
        )

        // Step 4: Check processing status if needed
        if let processingInfo = finalResponse.processingInfo {
            try await waitForProcessing(
                mediaId: mediaId,
                initialState: processingInfo.state,
                checkAfterSecs: processingInfo.checkAfterSecs ?? 1,
                accessToken: accessToken
            )
        }

        return mediaId
    }

    // MARK: - Private Methods

    /// Initialize the upload
    private func initUpload(totalBytes: Int, accessToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: Constants.XAPI.mediaUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "command=INIT&total_bytes=\(totalBytes)&media_type=image/jpeg&media_category=tweet_image"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 202 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MediaUploadError.uploadFailed(message)
        }

        let initResponse = try JSONDecoder().decode(MediaInitResponse.self, from: data)
        return initResponse.mediaIdString
    }

    /// Append a chunk of data
    private func appendChunk(mediaId: String, data: Data, segmentIndex: Int, accessToken: String) async throws {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: Constants.XAPI.mediaUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"command\"\r\n\r\n".data(using: .utf8)!)
        body.append("APPEND\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mediaId)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"segment_index\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(segmentIndex)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            let message = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw MediaUploadError.uploadFailed(message)
        }
    }

    /// Finalize the upload
    private func finalizeUpload(mediaId: String, accessToken: String) async throws -> MediaFinalizeResponse {
        var request = URLRequest(url: URL(string: Constants.XAPI.mediaUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "command=FINALIZE&media_id=\(mediaId)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MediaUploadError.uploadFailed(message)
        }

        return try JSONDecoder().decode(MediaFinalizeResponse.self, from: data)
    }

    /// Wait for server-side processing to complete
    private func waitForProcessing(
        mediaId: String,
        initialState: String,
        checkAfterSecs: Int,
        accessToken: String
    ) async throws {
        var state = initialState
        var waitTime = checkAfterSecs
        var attempts = 0
        let maxAttempts = 30 // Max ~30 seconds of waiting

        while state == "pending" || state == "in_progress" {
            attempts += 1
            if attempts > maxAttempts {
                throw MediaUploadError.timeout
            }

            try await Task.sleep(nanoseconds: UInt64(waitTime) * 1_000_000_000)

            // Check status
            var components = URLComponents(string: Constants.XAPI.mediaUploadURL)!
            components.queryItems = [
                URLQueryItem(name: "command", value: "STATUS"),
                URLQueryItem(name: "media_id", value: mediaId)
            ]

            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let statusResponse = try JSONDecoder().decode(MediaFinalizeResponse.self, from: data)

            if let processingInfo = statusResponse.processingInfo {
                state = processingInfo.state
                waitTime = processingInfo.checkAfterSecs ?? 1

                if state == "failed" {
                    throw MediaUploadError.processingFailed("Server processing failed")
                }
            } else {
                // No processing info means it's done
                break
            }
        }
    }

    /// Get a valid access token
    private func getValidAccessToken() async throws -> String {
        if let token = TokenStore.validAccessToken {
            return token
        }
        let tokens = try await oauthService.refreshAccessToken()
        return tokens.accessToken
    }
}
