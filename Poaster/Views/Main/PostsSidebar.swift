//
//  PostsSidebar.swift
//  Poaster
//

import SwiftUI
import SwiftData

/// Sidebar showing posted tweets with quick link access and drafts section
struct PostsSidebar: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState

    /// Query posted tweets sorted by most recent
    @Query(sort: \PostedTweet.postedAt, order: .reverse)
    private var postedTweets: [PostedTweet]

    /// Query all drafts sorted by most recently updated
    @Query(sort: \Draft.updatedAt, order: .reverse)
    private var allDrafts: [Draft]

    /// Filter drafts that haven't been posted yet
    private var drafts: [Draft] {
        allDrafts.filter { $0.status != .posted }
    }

    /// Binding to the selected draft
    @Binding var selectedDraft: Draft?

    /// Currently hovered tweet for showing action buttons
    @State private var hoveredTweetId: UUID?

    var body: some View {
        List(selection: $selectedDraft) {
            // Drafts section
            if !drafts.isEmpty {
                Section("Drafts") {
                    ForEach(drafts) { draft in
                        DraftRow(draft: draft)
                            .tag(draft)
                            .contextMenu {
                                draftContextMenu(for: draft)
                            }
                    }
                    .onDelete(perform: deleteDrafts)
                }
            }

            // Posted tweets section
            Section("Posted") {
                ForEach(groupedTweets, id: \.id) { group in
                    if group.tweets.count > 1 {
                        // Thread group
                        ThreadGroupRow(
                            tweets: group.tweets,
                            hoveredTweetId: $hoveredTweetId,
                            onCopyLink: copyLink,
                            onOpenInBrowser: openInBrowser
                        )
                    } else if let tweet = group.tweets.first {
                        // Single tweet
                        PostedTweetRow(
                            tweet: tweet,
                            isHovered: hoveredTweetId == tweet.id,
                            onCopyLink: { copyLink(tweet) },
                            onOpenInBrowser: { openInBrowser(tweet) }
                        )
                        .onHover { hovering in
                            hoveredTweetId = hovering ? tweet.id : nil
                        }
                        .contextMenu {
                            tweetContextMenu(for: tweet)
                        }
                    }
                }
                .onDelete(perform: deleteTweets)
            }
        }
        .navigationTitle("Posts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createDraft) {
                    Label("New Draft", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .overlay {
            if drafts.isEmpty && postedTweets.isEmpty {
                ContentUnavailableView {
                    Label("No Posts", systemImage: "doc.text")
                } description: {
                    Text("Create a new draft to get started.")
                } actions: {
                    Button("New Draft", action: createDraft)
                }
            }
        }
    }

    // MARK: - Tweet Grouping

    /// Group tweets by thread
    private var groupedTweets: [TweetGroup] {
        var groups: [TweetGroup] = []
        var threadGroups: [UUID: [PostedTweet]] = [:]
        var standaloneTweets: [PostedTweet] = []

        for tweet in postedTweets {
            if let threadId = tweet.threadId {
                threadGroups[threadId, default: []].append(tweet)
            } else {
                standaloneTweets.append(tweet)
            }
        }

        // Add thread groups (sorted by first tweet's date)
        for (threadId, tweets) in threadGroups {
            let sortedTweets = tweets.sorted { $0.threadPosition < $1.threadPosition }
            groups.append(TweetGroup(id: threadId, tweets: sortedTweets))
        }

        // Add standalone tweets
        for tweet in standaloneTweets {
            groups.append(TweetGroup(id: tweet.id, tweets: [tweet]))
        }

        // Sort groups by most recent
        return groups.sorted { group1, group2 in
            let date1 = group1.tweets.first?.postedAt ?? .distantPast
            let date2 = group2.tweets.first?.postedAt ?? .distantPast
            return date1 > date2
        }
    }

    // MARK: - Draft Actions

    private func createDraft() {
        let draft = Draft()
        // Add initial empty thread item
        let item = ThreadItem(sortOrder: 0)
        item.draft = draft
        draft.items.append(item)
        modelContext.insert(draft)
        selectedDraft = draft
    }

    private func duplicateDraft(_ draft: Draft) {
        let newDraft = Draft(status: .editing)
        modelContext.insert(newDraft)

        // Copy thread items
        for item in draft.sortedItems {
            let newItem = ThreadItem(
                text: item.text,
                sortOrder: item.sortOrder,
                status: .editing
            )
            newItem.draft = newDraft
            modelContext.insert(newItem)

            // Copy images
            for image in item.sortedImages {
                let newImage = DraftImage(
                    imageData: image.imageData,
                    thumbnailData: image.thumbnailData,
                    altText: image.altText,
                    sortOrder: image.sortOrder
                )
                newImage.threadItem = newItem
                modelContext.insert(newImage)
            }
        }

        selectedDraft = newDraft
    }

    private func deleteDrafts(at offsets: IndexSet) {
        for index in offsets {
            let draft = drafts[index]
            if selectedDraft?.id == draft.id {
                selectedDraft = nil
            }
            modelContext.delete(draft)
        }
    }

    private func deleteDraft(_ draft: Draft) {
        if selectedDraft?.id == draft.id {
            selectedDraft = nil
        }
        modelContext.delete(draft)
    }

    // MARK: - Tweet Actions

    private func copyLink(_ tweet: PostedTweet) {
        guard let urlString = tweet.tweetURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
    }

    private func openInBrowser(_ tweet: PostedTweet) {
        guard let url = tweet.url else { return }
        openURL(url)
    }

    private func deleteTweets(at offsets: IndexSet) {
        let groups = groupedTweets
        for index in offsets {
            let group = groups[index]
            for tweet in group.tweets {
                modelContext.delete(tweet)
            }
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func draftContextMenu(for draft: Draft) -> some View {
        Button("Duplicate") {
            duplicateDraft(draft)
        }

        Divider()

        Button("Delete", role: .destructive) {
            deleteDraft(draft)
        }
    }

    @ViewBuilder
    private func tweetContextMenu(for tweet: PostedTweet) -> some View {
        Button("Copy Link") {
            copyLink(tweet)
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        Button("Open in Browser") {
            openInBrowser(tweet)
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])

        Divider()

        Button("Delete", role: .destructive) {
            modelContext.delete(tweet)
        }
    }
}

// MARK: - Supporting Types

/// Groups tweets for display (thread or standalone)
private struct TweetGroup: Identifiable {
    let id: UUID
    let tweets: [PostedTweet]
}

/// Row for a single posted tweet
struct PostedTweetRow: View {
    let tweet: PostedTweet
    let isHovered: Bool
    let onCopyLink: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .lineLimit(1)
                    .font(.body)

                HStack {
                    if tweet.imageCount > 0 {
                        Label("\(tweet.imageCount)", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(tweet.postedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onCopyLink) {
                        Image(systemName: "link")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy link")

                    Button(action: onOpenInBrowser) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in browser")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var previewText: String {
        let trimmed = tweet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Posted" : trimmed
    }
}

/// Row for a thread group
struct ThreadGroupRow: View {
    let tweets: [PostedTweet]
    @Binding var hoveredTweetId: UUID?
    let onCopyLink: (PostedTweet) -> Void
    let onOpenInBrowser: (PostedTweet) -> Void

    var body: some View {
        DisclosureGroup {
            ForEach(tweets) { tweet in
                PostedTweetRow(
                    tweet: tweet,
                    isHovered: hoveredTweetId == tweet.id,
                    onCopyLink: { onCopyLink(tweet) },
                    onOpenInBrowser: { onOpenInBrowser(tweet) }
                )
                .onHover { hovering in
                    hoveredTweetId = hovering ? tweet.id : nil
                }
            }
        } label: {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.secondary)
                Text("Thread (\(tweets.count) posts)")
                    .font(.body)
            }
        }
    }
}

/// Row for a draft in the sidebar
struct DraftRow: View {
    let draft: Draft

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                Text(previewText)
                    .lineLimit(1)
                    .font(.body)

                if draft.items.count > 1 {
                    Text("(\(draft.items.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if draft.totalImageCount > 0 {
                    Label("\(draft.totalImageCount)", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(draft.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var previewText: String {
        let trimmed = draft.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Draft" : trimmed
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch draft.status {
        case .editing:
            Image(systemName: "pencil.circle")
                .foregroundStyle(.blue)
        case .ready:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
        case .posting:
            ProgressView()
                .scaleEffect(0.6)
        case .posted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    @Previewable @State var selectedDraft: Draft?
    PostsSidebar(selectedDraft: $selectedDraft)
        .environment(AppState())
        .modelContainer(for: [Draft.self, ThreadItem.self, DraftImage.self, PostedTweet.self], inMemory: true)
}
