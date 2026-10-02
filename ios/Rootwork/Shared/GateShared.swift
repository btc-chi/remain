import Foundation
import FamilyControls
import ManagedSettings

/// Shared between the app and the GateMonitor extension through the App Group.
enum GateShared {
    static let appGroup = "group.app.rootwork"
    static let storeName = ManagedSettingsStore.Name("rootwork.gate")
    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroup)! }

    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: "selection"),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return .init() }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "selection") }
    }

    /// Start of the last day Rootwork was completed.
    static var lastCompletedDay: Date? {
        get { defaults.object(forKey: "lastCompletedDay") as? Date }
        set { defaults.set(newValue, forKey: "lastCompletedDay") }
    }

    static var emergencyUnlocks: [Date] {
        get { (defaults.array(forKey: "emergencyUnlocks") as? [Date]) ?? [] }
        set { defaults.set(newValue, forKey: "emergencyUnlocks") }
    }

    static var completedToday: Bool {
        guard let last = lastCompletedDay else { return false }
        return Calendar.current.isDateInToday(last)
    }

    static func rest() {
        let s = selection
        let store = ManagedSettingsStore(named: storeName)
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }

    static func open() {
        ManagedSettingsStore(named: storeName).clearAllSettings()
    }
}
