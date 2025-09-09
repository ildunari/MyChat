//
//  MyChatApp.swift
//  MyChat
//
//  Created by Kosta Milovanovic on 9/8/25.
//

import SwiftUI
import SwiftData

@main
struct MyChatApp: App {
    // Create the SwiftData container for our models
    let container: ModelContainer = {
        let schema = Schema([Chat.self, Message.self, AppSettings.self])
        let config = ModelConfiguration()
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    // Create a single SettingsStore and keep it alive for the app’s lifetime
    @State private var settingsStore: SettingsStore

    init() {
        _settingsStore = State(initialValue: SettingsStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsStore) // Make SettingsStore available to all views
        }
        .modelContainer(container) // Attach the SwiftData container
    }
}
