//
//  NoteChatApp.swift
//  NoteChat
//
//  Created by Kosta Milovanovic on 9/8/25.
//

import SwiftUI
import SwiftData
import Foundation

#if DEBUG
// InjectionIII Hot Reload Support
// Load the injection bundle on app startup for instant code updates without rebuilding
// This is only active in DEBUG builds and has zero impact on release builds
extension Bundle {
    static let loadInjection: () = {
        #if targetEnvironment(simulator)
        let candidates: [String] = [
            Bundle.main.path(forResource: "iOSInjection", ofType: "bundle"),
            "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle"
        ].compactMap { $0 }

        for path in candidates {
            if let bundle = Bundle(path: path) {
                bundle.load()
                break
            }
        }
        #endif
    }()
}
#endif

@main
struct NoteChatApp: App {
    // Create the SwiftData container for our models, with safe recovery on failure
    let container: ModelContainer = {
        let schema = Schema([
            Chat.self, 
            Message.self, 
            AppSettings.self, 
            NoteFolder.self, 
            Note.self, 
            NoteRevision.self,
            MediaCanvas.self,
            MediaAsset.self
        ])

        // Resolve a stable store URL in Application Support
        let storeURL: URL = {
            let fm = FileManager.default
            let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let baseDir: URL
            if let asURL = appSupport {
                // Ensure the subdirectory for our bundle exists
                let bundleID = Bundle.main.bundleIdentifier ?? "NoteChat"
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
        #if DEBUG
        _ = Bundle.loadInjection
        #endif
        Self.purgeLegacyChatsIfNeeded(context: container.mainContext)
        _settingsStore = State(initialValue: SettingsStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            AppThemeView { RootView() }
            .environment(settingsStore) // Make SettingsStore available to all views
        }
        .modelContainer(container) // Attach the SwiftData container
    }

    private static func purgeLegacyChatsIfNeeded(context: ModelContext) {
        let key = "didPurgeChatsOct2025"
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: key) == false else { return }

        let fetch = FetchDescriptor<Chat>()
        if let chats = try? context.fetch(fetch), chats.isEmpty == false {
            for chat in chats { context.delete(chat) }
            try? context.save()
        }

        defaults.set(true, forKey: key)
    }
}
