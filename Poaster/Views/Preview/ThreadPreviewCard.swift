//
//  ThreadPreviewCard.swift
//  Poaster
//

import SwiftUI

/// A single post card within the thread preview, with visual connectors
struct ThreadPreviewCard: View {
    @Environment(AppState.self) private var appState

    let item: ThreadItem
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar column with thread connectors
            VStack(spacing: 0) {
                // Incoming connector (from previous post)
                if !isFirst {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 16)
                } else {
                    Color.clear.frame(width: 2, height: 16)
                }

                // Avatar
                avatarView

                // Outgoing connector (to next post)
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 40)

            // Post content
            VStack(alignment: .leading, spacing: 8) {
                // User info
                HStack(spacing: 4) {
                    Text(displayName)
                        .fontWeight(.semibold)
                    Text("@\(username)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                // Post text
                if !item.text.isEmpty {
                    AttributedPostText(text: item.text)
                        .font(.callout)
                } else {
                    Text("Empty post")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .italic()
                }

                // Images preview
                if !item.images.isEmpty {
                    PreviewImageGrid(images: item.sortedImages)
                        .frame(maxHeight: 120)
                }

                // Character count for this item
                CharacterCountView(text: item.text)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Circle()
            .fill(Color.blue.gradient)
            .frame(width: 40, height: 40)
            .overlay {
                if let user = appState.currentUser {
                    Text(user.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                }
            }
    }

    // MARK: - User Info

    private var displayName: String {
        appState.currentUser?.name ?? "Your Name"
    }

    private var username: String {
        appState.currentUser?.username ?? "username"
    }
}

/// Button to add a new item to the thread
struct AddThreadItemButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add to thread")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.tertiary)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        ThreadPreviewCard(
            item: ThreadItem(text: "First post in thread", sortOrder: 0),
            isSelected: true,
            isFirst: true,
            isLast: false
        )

        ThreadPreviewCard(
            item: ThreadItem(text: "Second post with more content. This is a longer message.", sortOrder: 1),
            isSelected: false,
            isFirst: false,
            isLast: true
        )

        AddThreadItemButton { }
    }
    .padding()
    .frame(width: 320)
    .environment(AppState())
}
