import Foundation

class AppGroupManager {
    static let shared = AppGroupManager()

    let userDefaults: UserDefaults?
    let containerURL: URL?

    private init() {
        userDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier)
        containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
        )
    }

    // MARK: - UserDefaults Convenience

    func getString(forKey key: String) -> String? {
        userDefaults?.string(forKey: key)
    }

    func setString(_ value: String?, forKey key: String) {
        userDefaults?.set(value, forKey: key)
        userDefaults?.synchronize()
    }

    func getBool(forKey key: String) -> Bool {
        userDefaults?.bool(forKey: key) ?? false
    }

    func setBool(_ value: Bool, forKey key: String) {
        userDefaults?.set(value, forKey: key)
        userDefaults?.synchronize()
    }

    func getData(forKey key: String) -> Data? {
        userDefaults?.data(forKey: key)
    }

    func setData(_ data: Data?, forKey key: String) {
        userDefaults?.set(data, forKey: key)
        userDefaults?.synchronize()
    }

    // MARK: - Pending Clip

    func setPendingClip(_ clipRequest: ClipRequest) {
        do {
            let data = try JSONEncoder().encode(clipRequest)
            setData(data, forKey: SharedConstants.pendingClipKey)
        } catch {
            print("Failed to encode clip request: \(error)")
        }
    }

    func getPendingClip() -> ClipRequest? {
        guard let data = getData(forKey: SharedConstants.pendingClipKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ClipRequest.self, from: data)
        } catch {
            print("Failed to decode clip request: \(error)")
            return nil
        }
    }

    func clearPendingClip() {
        setData(nil, forKey: SharedConstants.pendingClipKey)
    }

    // MARK: - File Storage

    func writeFile(name: String, data: Data) throws {
        guard let containerURL = containerURL else {
            throw AppGroupError.containerNotAvailable
        }

        let fileURL = containerURL.appendingPathComponent(name)
        try data.write(to: fileURL)
    }

    func readFile(name: String) throws -> Data {
        guard let containerURL = containerURL else {
            throw AppGroupError.containerNotAvailable
        }

        let fileURL = containerURL.appendingPathComponent(name)
        return try Data(contentsOf: fileURL)
    }

    func deleteFile(name: String) throws {
        guard let containerURL = containerURL else {
            throw AppGroupError.containerNotAvailable
        }

        let fileURL = containerURL.appendingPathComponent(name)
        try FileManager.default.removeItem(at: fileURL)
    }
}

enum AppGroupError: Error {
    case containerNotAvailable
}
