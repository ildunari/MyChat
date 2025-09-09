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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Chat.self,
            Message.self,
            AppSettings.self
        ])
        // Persist to Application Support with a stable file name so we can recover from corruption
        let fm = FileManager.default
        let baseDir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let storeURL = baseDir.appendingPathComponent("MyChat.sqlite")
        let config = ModelConfiguration("Default", schema: schema, url: storeURL, allowsSave: true)

        func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [config])
        }

        do {
            return try makeContainer()
        } catch {
            // Attempt a one-time recovery by removing the SQLite store and sidecars, then recreate
            let db = storeURL // e.g., .../MyChat.sqlite
            let wal = db.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let shm = db.deletingPathExtension().appendingPathExtension("sqlite-shm")
            for url in [db, wal, shm] { try? fm.removeItem(at: url) }
            do {
                return try makeContainer()
            } catch {
                // Final fallback: non‑crashing in‑memory container to keep the app usable
                let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                if let fallback = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                    return fallback
                }
                // If even in‑memory fails, crash with context
                fatalError("Could not create ModelContainer (persistent or in‑memory): \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}