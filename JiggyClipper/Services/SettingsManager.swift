import Foundation

class SettingsManager {
    static let shared = SettingsManager()

    private let appGroup = AppGroupManager.shared

    private init() {}

    var defaultVault: String {
        get { appGroup.userDefaults?.string(forKey: "defaultVault") ?? "" }
        set { appGroup.userDefaults?.set(newValue, forKey: "defaultVault") }
    }

    var defaultTemplateId: String? {
        get { appGroup.userDefaults?.string(forKey: "defaultTemplate") }
        set { appGroup.userDefaults?.set(newValue, forKey: "defaultTemplate") }
    }

    var autoClip: Bool {
        get { appGroup.userDefaults?.bool(forKey: "autoClip") ?? false }
        set { appGroup.userDefaults?.set(newValue, forKey: "autoClip") }
    }
}
