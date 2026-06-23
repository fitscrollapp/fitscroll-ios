import Foundation

/// Shared rolling debug log that the main app AND the
/// DeviceActivityMonitor extension both append to, via a UserDefaults
/// suite in the app group. Used when we need to inspect what happened
/// inside the extension after the main app has resumed — os_log isn't
/// recoverable from the device without USB, but this survives across
/// process restarts and is visible in the in-app debug screen.
enum SharedDebugLog {

    private static let appGroupID = "group.com.huseyinbabal.fitscroll"
    private static let logKey = "fitscroll.debugLog.v1"
    private static let maxEntries = 200

    struct Entry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let category: String
        let message: String

        init(category: String, message: String) {
            self.id = UUID()
            self.timestamp = Date()
            self.category = category
            self.message = message
        }
    }

    static func log(_ message: String, category: String = "app") {
        let entry = Entry(category: category, message: message)
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return
        }

        var entries = loadEntries(from: defaults)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: logKey)
        }
    }

    static func entries() -> [Entry] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return []
        }
        return loadEntries(from: defaults).reversed()
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        defaults.removeObject(forKey: logKey)
    }

    private static func loadEntries(from defaults: UserDefaults) -> [Entry] {
        guard let data = defaults.data(forKey: logKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }
}
