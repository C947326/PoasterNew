//
//  Draft.swift
//  Poaster
//

import Foundation
import SwiftData

/// Status of a draft in its lifecycle
enum DraftStatus: String, Codable, CaseIterable {
    case editing    // Currently being composed
    case ready      // Ready to post
    case posting    // Currently being posted to X
    case posted     // Successfully posted
    case failed     // Posting failed, can retry
}

/// A draft thread container that holds one or more posts
/// Single posts are simply threads with one item
@Model
final class Draft {
    var id: UUID

    /// Thread items (posts) in this draft
    @Relationship(deleteRule: .cascade, inverse: \ThreadItem.draft)
    var items: [ThreadItem]

    /// Overall status of the draft
    var status: DraftStatus

    var createdAt: Date
    var updatedAt: Date

    /// Error message if posting failed
    var failureMessage: String?

    init(
        id: UUID = UUID(),
        items: [ThreadItem] = [],
        status: DraftStatus = .editing,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.items = items
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convenience initializer for single-post drafts (backwards compatible)
    convenience init(
        id: UUID = UUID(),
        text: String,
        status: DraftStatus = .editing,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let item = ThreadItem(text: text, sortOrder: 0, status: status)
        self.init(
            id: id,
            items: [item],
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Items sorted by their position in the thread
    var sortedItems: [ThreadItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Preview text from the first item
    var previewText: String {
        sortedItems.first?.text ?? ""
    }

    /// Total image count across all items
    var totalImageCount: Int {
        items.reduce(0) { $0 + $1.images.count }
    }

    /// Whether this draft can be edited
    var isEditable: Bool {
        status == .editing || status == .ready || status == .failed
    }

    /// Whether this draft can be posted
    var canPost: Bool {
        let hasContent = items.contains { $0.hasContent }
        return hasContent && (status == .editing || status == .ready || status == .failed)
    }

    /// Touch the updatedAt timestamp
    func touch() {
        updatedAt = Date()
    }

    /// Add a new thread item at the end
    func addItem() -> ThreadItem {
        let newOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        let item = ThreadItem(sortOrder: newOrder)
        items.append(item)
        touch()
        return item
    }

    /// Remove a thread item and reorder remaining items
    func removeItem(_ item: ThreadItem) {
        items.removeAll { $0.id == item.id }
        // Reorder remaining items
        for (index, remainingItem) in sortedItems.enumerated() {
            remainingItem.sortOrder = index
        }
        touch()
    }
}
