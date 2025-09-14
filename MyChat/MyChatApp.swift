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
    // Create the SwiftData container for our models, with safe recovery on failure
    let container: ModelContainer = {
        let schema = Schema([Chat.self, Message.self, AppSettings.self, Note.self, NoteFolder.self])

        // Resolve a stable store URL in Application Support
        let storeURL: URL = {
            let fm = FileManager.default
            let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let baseDir: URL
            if let asURL = appSupport {
                // Ensure the subdirectory for our bundle exists
                let bundleID = Bundle.main.bundleIdentifier ?? "MyChat"
                let dir = asURL.appendingPathComponent(bundleID, isDirectory: true)
                if !fm.fileExists(atPath: dir.path) {
                    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                baseDir = dir
            } else {
                // Fallback to Documents if Application Support is unavailable
                baseDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            }
            return baseDir.appendingPathComponent("Store.sqlite", isDirectory: false)
        }()

        func makeConfig(inMemory: Bool = false) -> ModelConfiguration {
            if inMemory {
                return ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                return ModelConfiguration(url: storeURL)
            }
        }

        // Helper to destroy SQLite primary and aux files
        func destroyStoreFiles(at url: URL) {
            let fm = FileManager.default
            let sqlite = url
            let wal = URL(fileURLWithPath: url.path + "-wal")
            let shm = URL(fileURLWithPath: url.path + "-shm")
            for u in [sqlite, wal, shm] {
                if fm.fileExists(atPath: u.path) {
                    try? fm.removeItem(at: u)
                }
            }
        }

        // 1) First attempt: normal on-disk store
        do {
            return try ModelContainer(for: schema, configurations: [makeConfig()])
        } catch {
            // 2) Destroy and retry once
            destroyStoreFiles(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [makeConfig()])
            } catch {
                // 3) Fall back to in-memory so the app can still run
                return try! ModelContainer(for: schema, configurations: [makeConfig(inMemory: true)])
            }
        }
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
