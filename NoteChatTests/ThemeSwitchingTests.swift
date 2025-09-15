import XCTest
import SwiftData
@testable import MyChat

final class ThemeSwitchingTests: XCTestCase {
    func testThemeSwitchingUpdatesSettings() throws {
        let container = try ModelContainer(for: AppSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let store = SettingsStore(context: context)
        store.interfaceTheme = "dark"
        store.save()
        let fetch = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(fetch).first
        XCTAssertEqual(settings?.interfaceTheme, "dark")
    }
}
