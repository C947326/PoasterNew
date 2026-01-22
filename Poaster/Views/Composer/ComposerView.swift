//
//  ComposerView.swift
//  Poaster
//

import SwiftUI
import SwiftData
import PhotosUI

/// The main composer view for editing a thread item's text and managing images
struct ComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    /// The thread item being edited
    @Bindable var item: ThreadItem

    /// The parent draft (for posting the entire thread)
    let draft: Draft

    /// Selected photos from PhotosPicker
    @State private var selectedPhotos: [PhotosPickerItem] = []

    /// Error message for posting failures
    @State private var postingError: String?

    /// Whether to show the success alert
    @State private var showingPostSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Text editor
            TextEditor(text: $item.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding()
                .onChange(of: item.text) { _, _ in
                    draft.touch()
                }

            Divider()

            // Image grid
            if !item.images.isEmpty {
                ImageGridView(item: item)
                    .padding()
                Divider()
            }

            // Bottom toolbar
            composerToolbar
        }
        .navigationTitle("Compose")
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await processSelectedPhotos(newPhotos)
            }
        }
        .alert("Posted!", isPresented: $showingPostSuccess) {
            Button("OK") { }
        } message: {
            let count = draft.items.count
            if count > 1 {
                Text("Your thread of \(count) posts has been published to X.")
            } else {
                Text("Your post has been published to X.")
            }
        }
        .alert("Posting Failed", isPresented: .init(
            get: { postingError != nil },
            set: { if !$0 { postingError = nil } }
        )) {
            Button("OK") { postingError = nil }
        } message: {
            Text(postingError ?? "Unknown error")
        }
    }

    /// Bottom toolbar with add image button, character count, and post button
    private var composerToolbar: some View {
        HStack {
            // Add image button
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: Constants.Images.maxCount - item.images.count,
                matching: .images
            ) {
                Label("Add Image", systemImage: "photo")
            }
            .disabled(item.images.count >= Constants.Images.maxCount)

            Spacer()

            // Character count for current item
            CharacterCountView(text: item.text)

            // Post button (posts entire draft/thread)
            Button(action: postDraft) {
                if appState.isPosting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(draft.items.count > 1 ? "Post Thread" : "Post")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canPost || appState.isPosting || !appState.isAuthenticated)
        }
        .padding()
    }

    /// Process selected photos and add them to the thread item
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for pickerItem in items {
            guard item.images.count < Constants.Images.maxCount else { break }

            if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    addImage(data: data)
                }
            }
        }

        // Clear selection
        await MainActor.run {
            selectedPhotos = []
        }
    }

    /// Add an image to the thread item
    private func addImage(data: Data) {
        guard let processed = ImageProcessor.process(data) else { return }

        let draftImage = DraftImage(
            imageData: processed.imageData,
            thumbnailData: processed.thumbnailData,
            sortOrder: item.images.count
        )
        draftImage.threadItem = item
        modelContext.insert(draftImage)
        draft.touch()
    }

    /// Post the entire draft (all thread items) to X
    private func postDraft() {
        Task {
            appState.isPosting = true

            do {
                _ = try await appState.postComposer.post(draft: draft, modelContext: modelContext)
                await MainActor.run {
                    appState.isPosting = false
                    showingPostSuccess = true
                }
            } catch {
                await MainActor.run {
                    appState.isPosting = false
                    postingError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    let draft = Draft()
    let item = ThreadItem(text: "Hello, X! This is a test post.", sortOrder: 0)
    item.draft = draft
    draft.items = [item]

    return ComposerView(item: item, draft: draft)
        .environment(AppState())
        .modelContainer(for: [Draft.self, ThreadItem.self, DraftImage.self], inMemory: true)
}
