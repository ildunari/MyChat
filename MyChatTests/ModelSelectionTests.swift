import XCTest
import SwiftData
@testable import MyChat

final class ModelSelectionTests: XCTestCase {
    func testModelSelectionUpdatesEnabledModels() throws {
        let container = try ModelContainer(for: AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let store = SettingsStore(context: context)
        store.openAIEnabled.insert("gpt-test")
        store.save()
        let fetch = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(fetch).first
        XCTAssertTrue(settings?.openAIEnabledModels.contains("gpt-test") ?? false)
    }
}
