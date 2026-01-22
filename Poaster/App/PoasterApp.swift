//
//  PoasterApp.swift
//  Poaster
//

import SwiftUI
import SwiftData

@main
struct PoasterApp: App {
    /// Global application state injected via environment
    @State private var appState = AppState()

    /// SwiftData model container for persistence
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Draft.self,
            ThreadItem.self,
            DraftImage.self,
            PostedTweet.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Draft") {
                    NotificationCenter.default.post(
                        name: .createNewDraft,
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewDraft = Notification.Name("createNewDraft")
}
