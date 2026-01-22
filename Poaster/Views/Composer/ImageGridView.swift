//
//  ImageGridView.swift
//  Poaster
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Grid view for displaying and managing images in the composer
struct ImageGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ThreadItem

    /// Whether an image is being dragged
    @State private var draggingImage: DraftImage?

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(sortedImages) { image in
                ImageTile(image: image, onDelete: { deleteImage(image) })
                    .aspectRatio(1, contentMode: .fit)
                    .onDrag {
                        draggingImage = image
                        return NSItemProvider(object: image.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ImageDropDelegate(
                        item: image,
                        items: sortedImages,
                        draggingItem: $draggingImage,
                        onReorder: reorderImages
                    ))
            }
        }
    }

    /// Images sorted by their sort order
    private var sortedImages: [DraftImage] {
        item.images.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Grid columns based on image count
    private var columns: [GridItem] {
        let count = min(item.images.count, 4)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: max(count, 2))
    }

    /// Delete an image from the thread item
    private func deleteImage(_ image: DraftImage) {
        withAnimation {
            modelContext.delete(image)
            // Reorder remaining images
            for (index, img) in sortedImages.filter({ $0.id != image.id }).enumerated() {
                img.sortOrder = index
            }
            item.draft?.touch()
        }
    }

    /// Reorder images after drag and drop
    private func reorderImages(_ images: [DraftImage]) {
        for (index, image) in images.enumerated() {
            image.sortOrder = index
        }
        item.draft?.touch()
    }
}

/// A single image tile in the grid
struct ImageTile: View {
    let image: DraftImage
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            if let nsImage = image.thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
            }

            // Delete button (shown on hover)
            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

/// Drop delegate for reordering images
struct ImageDropDelegate: DropDelegate {
    let item: DraftImage
    let items: [DraftImage]
    @Binding var draggingItem: DraftImage?
    let onReorder: ([DraftImage]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id })
        else { return }

        var reordered = items
        reordered.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        onReorder(reordered)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    let item = ThreadItem(text: "Test")
    return ImageGridView(item: item)
        .modelContainer(for: [Draft.self, ThreadItem.self, DraftImage.self], inMemory: true)
        .frame(width: 400, height: 300)
}
