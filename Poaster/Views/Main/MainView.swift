//
//  MainView.swift
//  Poaster
//

import SwiftUI
import SwiftData

/// The main two-column layout with collapsible inspector: Sidebar | Composer + Inspector
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    /// Currently selected draft
    @State private var selectedDraft: Draft?

    /// Currently selected thread item for editing
    @State private var selectedThreadItem: ThreadItem?

    /// Whether the inspector panel is visible
    @State private var showInspector = true

    var body: some View {
        NavigationSplitView {
            PostsSidebar(selectedDraft: $selectedDraft)
                .navigationSplitViewColumnWidth(
                    min: Constants.UI.sidebarMinWidth,
                    ideal: Constants.UI.sidebarIdealWidth
                )
        } detail: {
            if let item = selectedThreadItem {
                ComposerView(item: item, draft: selectedDraft!)
            } else if selectedDraft != nil {
                ContentUnavailableView(
                    "Select a Post",
                    systemImage: "text.cursor",
                    description: Text("Select a post from the thread preview to edit it.")
                )
            } else {
                ContentUnavailableView(
                    "No Draft Selected",
                    systemImage: "doc.text",
                    description: Text("Select a draft from the sidebar or create a new one.")
                )
            }
        }
        .inspector(isPresented: $showInspector) {
            if let draft = selectedDraft {
                ThreadInspector(
                    draft: draft,
                    selectedItem: $selectedThreadItem
                )
            } else {
                ContentUnavailableView(
                    "Preview",
                    systemImage: "eye",
                    description: Text("Select a draft to preview how it will appear on X.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AuthStatusView()
            }

            ToolbarItem {
                Button {
                    withAnimation {
                        showInspector.toggle()
                    }
                } label: {
                    Label("Preview", systemImage: "sidebar.right")
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .help("Toggle thread preview")
            }
        }
        .onChange(of: selectedDraft) { _, newDraft in
            // When draft changes, select its first item
            if let draft = newDraft {
                selectedThreadItem = draft.sortedItems.first
            } else {
                selectedThreadItem = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewDraft)) { _ in
            createNewDraft()
        }
        .task {
            await restoreSession()
        }
    }

    /// Restore user session from stored tokens if available
    private func restoreSession() async {
        guard TokenStore.hasTokens else { return }

        do {
            let user = try await appState.apiClient.getCurrentUser()
            appState.currentUser = user
        } catch {
            // Token invalid/expired - clear and let user re-auth
            try? TokenStore.delete()
        }
    }

    /// Create a new draft and select it
    private func createNewDraft() {
        let draft = Draft()
        let item = ThreadItem(sortOrder: 0)
        item.draft = draft
        draft.items.append(item)
        modelContext.insert(draft)
        selectedDraft = draft
        selectedThreadItem = item
    }
}

#Preview {
    MainView()
        .environment(AppState())
        .modelContainer(for: [Draft.self, ThreadItem.self, DraftImage.self, PostedTweet.self], inMemory: true)
}
