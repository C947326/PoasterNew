//
//  PostComposer.swift
//  Poaster
//

import Foundation
import SwiftData

/// Orchestrates the process of posting a draft thread to X
/// Handles image uploads, tweet creation, reply chaining, and status updates
@Observable
final class PostComposer {

    private let apiClient: XAPIClient
    private let mediaUploader: MediaUploader

    /// Progress of the current posting operation (0.0 - 1.0)
    var progress: Double = 0

    /// Current status message
    var statusMessage: String = ""

    init(apiClient: XAPIClient, mediaUploader: MediaUploader) {
        self.apiClient = apiClient
        self.mediaUploader = mediaUploader
    }

    /// Post a draft thread to X
    /// - Parameters:
    ///   - draft: The draft containing thread items to post
    ///   - modelContext: SwiftData context for creating PostedTweet records
    /// - Returns: Array of created PostedTweets
    @MainActor
    func post(draft: Draft, modelContext: ModelContext) async throws -> [PostedTweet] {
        // Update draft status
        draft.status = .posting
        progress = 0
        statusMessage = "Preparing..."

        let sortedItems = draft.sortedItems.filter { $0.hasContent }

        guard !sortedItems.isEmpty else {
            throw PostComposerError.emptyContent
        }

        do {
            var postedTweets: [PostedTweet] = []
            var previousTweetId: String? = nil

            // Use a thread ID only if there are multiple items
            let threadId = sortedItems.count > 1 ? UUID() : nil

            // Calculate total work units for progress
            let totalImages = sortedItems.reduce(0) { $0 + $1.images.count }
            let totalWork = Double(totalImages) + Double(sortedItems.count)
            var completedWork: Double = 0

            for (index, item) in sortedItems.enumerated() {
                item.status = .posting

                // Upload images for this item
                var mediaIds: [String] = []
                if !item.images.isEmpty {
                    let sortedImages = item.sortedImages
                    for (imageIndex, image) in sortedImages.enumerated() {
                        statusMessage = "Uploading image \(imageIndex + 1) of \(sortedImages.count) for post \(index + 1)..."

                        let mediaId = try await mediaUploader.uploadImage(image.imageData)
                        image.uploadedMediaId = mediaId
                        mediaIds.append(mediaId)

                        completedWork += 1
                        progress = completedWork / totalWork
                    }
                }

                // Post the tweet with reply chain
                statusMessage = sortedItems.count > 1
                    ? "Posting \(index + 1) of \(sortedItems.count)..."
                    : "Posting..."

                let response = try await apiClient.postTweet(
                    text: item.text,
                    mediaIds: mediaIds.isEmpty ? nil : mediaIds,
                    replyToTweetId: previousTweetId
                )

                // Mark item as posted
                item.status = .posted
                item.postedTweetId = response.data.id

                // Create posted tweet record
                let postedTweet = PostedTweet(
                    tweetId: response.data.id,
                    text: response.data.text,
                    imageCount: item.images.count,
                    tweetURL: "https://x.com/i/status/\(response.data.id)",
                    threadPosition: index,
                    threadId: threadId
                )
                modelContext.insert(postedTweet)
                postedTweets.append(postedTweet)

                // Chain next reply to this tweet
                previousTweetId = response.data.id

                completedWork += 1
                progress = completedWork / totalWork
            }

            // Update draft status
            draft.status = .posted

            progress = 1.0
            statusMessage = sortedItems.count > 1 ? "Thread posted!" : "Posted!"

            return postedTweets

        } catch {
            // Update draft and items with failure
            draft.status = .failed
            draft.failureMessage = error.localizedDescription

            for item in draft.items where item.status == .posting {
                item.status = .failed
            }

            progress = 0
            statusMessage = "Failed: \(error.localizedDescription)"

            throw error
        }
    }

    /// Retry posting a failed draft
    @MainActor
    func retry(draft: Draft, modelContext: ModelContext) async throws -> [PostedTweet] {
        guard draft.status == .failed else {
            throw PostComposerError.invalidState
        }

        // Clear previous failure state
        draft.failureMessage = nil

        // Reset failed items and clear uploaded media IDs
        for item in draft.items {
            if item.status == .failed {
                item.status = .editing
            }
            for image in item.images {
                image.uploadedMediaId = nil
            }
        }

        return try await post(draft: draft, modelContext: modelContext)
    }
}

/// Errors specific to post composition
enum PostComposerError: LocalizedError {
    case invalidState
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "Draft is not in a valid state for this operation"
        case .emptyContent:
            return "Cannot post empty content"
        }
    }
}
