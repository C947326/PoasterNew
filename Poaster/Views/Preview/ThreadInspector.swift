//
//  ThreadInspector.swift
//  Poaster
//

import SwiftUI
import SwiftData

/// Inspector panel showing thread preview with navigation and editing controls
struct ThreadInspector: View {
    @Environment(\.modelContext) private var modelContext

    let draft: Draft
    @Binding var selectedItem: ThreadItem?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Thread count badge (only for multi-post threads)
                    if draft.items.count > 1 {
                        ThreadCountBadge(count: draft.items.count)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }

                    // Thread items
                    ForEach(draft.sortedItems) { item in
                        ThreadPreviewCard(
                            item: item,
                            isSelected: item.id == selectedItem?.id,
                            isFirst: item.id == draft.sortedItems.first?.id,
                            isLast: item.id == draft.sortedItems.last?.id
                        )
                        .id(item.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedItem = item
                            }
                        }
                        .contextMenu {
                            itemContextMenu(for: item)
                        }
                    }

                    // Add to thread button
                    AddThreadItemButton {
                        addNewItem(scrollProxy: proxy)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
    }

    // MARK: - Actions

    private func addNewItem(scrollProxy: ScrollViewProxy) {
        let newItem = draft.addItem()
        modelContext.insert(newItem)

        // Select and scroll to new item
        withAnimation {
            selectedItem = newItem
            scrollProxy.scrollTo(newItem.id, anchor: .bottom)
        }
    }

    private func deleteItem(_ item: ThreadItem) {
        // Don't allow deleting the last item
        guard draft.items.count > 1 else { return }

        // If deleting selected item, select another
        if selectedItem?.id == item.id {
            if let index = draft.sortedItems.firstIndex(where: { $0.id == item.id }) {
                if index > 0 {
                    selectedItem = draft.sortedItems[index - 1]
                } else if draft.sortedItems.count > 1 {
                    selectedItem = draft.sortedItems[1]
                }
            }
        }

        draft.removeItem(item)
        modelContext.delete(item)
    }

    private func moveItemUp(_ item: ThreadItem) {
        guard let index = draft.sortedItems.firstIndex(where: { $0.id == item.id }),
              index > 0 else { return }

        let previousItem = draft.sortedItems[index - 1]
        let temp = item.sortOrder
        item.sortOrder = previousItem.sortOrder
        previousItem.sortOrder = temp
        draft.touch()
    }

    private func moveItemDown(_ item: ThreadItem) {
        let sorted = draft.sortedItems
        guard let index = sorted.firstIndex(where: { $0.id == item.id }),
              index < sorted.count - 1 else { return }

        let nextItem = sorted[index + 1]
        let temp = item.sortOrder
        item.sortOrder = nextItem.sortOrder
        nextItem.sortOrder = temp
        draft.touch()
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func itemContextMenu(for item: ThreadItem) -> some View {
        let sorted = draft.sortedItems
        let isFirst = item.id == sorted.first?.id
        let isLast = item.id == sorted.last?.id

        Button("Move Up") {
            moveItemUp(item)
        }
        .disabled(isFirst)

        Button("Move Down") {
            moveItemDown(item)
        }
        .disabled(isLast)

        Divider()

        Button("Delete", role: .destructive) {
            deleteItem(item)
        }
        .disabled(draft.items.count <= 1)
    }
}

// MARK: - Thread Count Badge

/// Badge displaying the number of posts in a thread
struct ThreadCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) posts")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.85))
            .clipShape(Capsule())
    }
}

#Preview {
    @Previewable @State var selectedItem: ThreadItem?

    let draft = Draft()
    let item1 = ThreadItem(text: "First post", sortOrder: 0)
    let item2 = ThreadItem(text: "Second post", sortOrder: 1)
    item1.draft = draft
    item2.draft = draft
    draft.items = [item1, item2]

    return ThreadInspector(draft: draft, selectedItem: $selectedItem)
        .frame(width: 320, height: 500)
        .environment(AppState())
        .modelContainer(for: [Draft.self, ThreadItem.self, DraftImage.self], inMemory: true)
}
