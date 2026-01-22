//
//  PostedTweet.swift
//  Poaster
//

import Foundation
import SwiftData

/// A record of a successfully posted tweet
@Model
final class PostedTweet {
    var id: UUID

    /// The tweet ID from X API
    var tweetId: String

    /// The text content that was posted
    var text: String

    /// Number of images that were attached
    var imageCount: Int

    /// When the tweet was posted
    var postedAt: Date

    /// URL to view the tweet on X
    var tweetURL: String?

    /// Position within a thread (0 = standalone or first in thread)
    var threadPosition: Int = 0

    /// Groups posts into threads (nil = standalone post)
    var threadId: UUID?

    init(
        id: UUID = UUID(),
        tweetId: String,
        text: String,
        imageCount: Int = 0,
        postedAt: Date = Date(),
        tweetURL: String? = nil,
        threadPosition: Int = 0,
        threadId: UUID? = nil
    ) {
        self.id = id
        self.tweetId = tweetId
        self.text = text
        self.imageCount = imageCount
        self.postedAt = postedAt
        self.tweetURL = tweetURL
        self.threadPosition = threadPosition
        self.threadId = threadId
    }

    /// Convenience URL accessor
    var url: URL? {
        tweetURL.flatMap { URL(string: $0) }
    }

    /// Whether this is part of a thread
    var isInThread: Bool {
        threadId != nil
    }

    /// Whether this is the first post in a thread
    var isThreadStart: Bool {
        threadId != nil && threadPosition == 0
    }
}
