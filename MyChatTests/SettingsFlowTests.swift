import XCTest
import SwiftData
@testable import NoteChat

@MainActor
final class SettingsFlowTests: XCTestCase {
    func testSettingsSavePersistsChanges() throws {
        let container = try ModelContainer(for: AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let store = SettingsStore(context: context)
        store.defaultModel = "new-model"
        store.interfaceTheme = "dark"
        store.save()
        let fetch = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(fetch).first
        XCTAssertEqual(settings?.defaultModel, "new-model")
        XCTAssertEqual(settings?.interfaceTheme, "dark")
    }
}
