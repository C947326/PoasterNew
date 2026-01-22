//
//  DraftImage.swift
//  Poaster
//

import Foundation
import SwiftData
import AppKit

/// An image attachment for a thread item post
@Model
final class DraftImage {
    var id: UUID

    /// Full resolution image data (JPEG)
    var imageData: Data

    /// Thumbnail image data for display in lists
    var thumbnailData: Data

    /// Alt text for accessibility
    var altText: String

    /// Sort order within the thread item (0-3)
    var sortOrder: Int

    /// Reference to parent thread item
    var threadItem: ThreadItem?

    /// Media ID returned from X API after upload
    var uploadedMediaId: String?

    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data,
        altText: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.altText = altText
        self.sortOrder = sortOrder
    }

    /// Create an NSImage from the full resolution data
    var image: NSImage? {
        NSImage(data: imageData)
    }

    /// Create an NSImage from the thumbnail data
    var thumbnail: NSImage? {
        NSImage(data: thumbnailData)
    }
}
