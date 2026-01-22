//
//  ThreadItem.swift
//  Poaster
//

import Foundation
import SwiftData

/// An individual post within a thread
/// A Draft contains one or more ThreadItems, enabling thread composition
@Model
final class ThreadItem {
    var id: UUID

    /// The text content of this post
    var text: String

    /// Images attached to this post
    @Relationship(deleteRule: .cascade, inverse: \DraftImage.threadItem)
    var images: [DraftImage]

    /// Position in the thread (0 = first post)
    var sortOrder: Int

    /// Reference to the parent draft/thread container
    var draft: Draft?

    /// The posted tweet ID if this item has been posted
    var postedTweetId: String?

    /// Current status of this thread item
    var status: DraftStatus

    init(
        id: UUID = UUID(),
        text: String = "",
        images: [DraftImage] = [],
        sortOrder: Int = 0,
        status: DraftStatus = .editing
    ) {
        self.id = id
        self.text = text
        self.images = images
        self.sortOrder = sortOrder
        self.status = status
    }

    /// Images sorted by their display order
    var sortedImages: [DraftImage] {
        images.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Whether this item can be edited
    var isEditable: Bool {
        status == .editing || status == .ready || status == .failed
    }

    /// Whether this item has content to post
    var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
    }
}
