import Foundation

class VaultManager {
    static let shared = VaultManager()

    private let bookmarkKey = "vaultBookmark"
    private let appGroup = AppGroupManager.shared

    private init() {}

    // MARK: - Vault Path Display

    /// Returns the display name of the selected vault (folder name)
    var vaultName: String? {
        guard let url = resolveBookmark() else { return nil }
        return url.lastPathComponent
    }

    /// Returns whether a vault has been selected
    var hasVault: Bool {
        appGroup.getData(forKey: bookmarkKey) != nil
    }

    // MARK: - Bookmark Management

    /// Saves a security-scoped bookmark for the selected vault folder
    func saveVaultBookmark(for url: URL) throws {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw VaultError.accessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // Create a security-scoped bookmark
        let bookmarkData = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        appGroup.setData(bookmarkData, forKey: bookmarkKey)
    }

    /// Resolves the saved bookmark to get the vault URL
    func resolveBookmark() -> URL? {
        guard let bookmarkData = appGroup.getData(forKey: bookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Try to refresh the bookmark
                try saveVaultBookmark(for: url)
            }

            return url
        } catch {
            print("Failed to resolve vault bookmark: \(error)")
            return nil
        }
    }

    /// Clears the saved vault bookmark
    func clearVault() {
        appGroup.setData(nil, forKey: bookmarkKey)
    }

    // MARK: - File Operations

    /// Writes a note to the vault
    func writeNote(name: String, content: String, path: String = "") throws {
        guard let vaultURL = resolveBookmark() else {
            throw VaultError.noVaultSelected
        }

        // Start accessing security-scoped resource
        guard vaultURL.startAccessingSecurityScopedResource() else {
            throw VaultError.accessDenied
        }

        defer {
            vaultURL.stopAccessingSecurityScopedResource()
        }

        // Build the full path
        var targetURL = vaultURL

        // Add subfolder path if specified
        if !path.isEmpty {
            let cleanPath = path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            targetURL = vaultURL.appendingPathComponent(cleanPath)

            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(
                at: targetURL,
                withIntermediateDirectories: true
            )
        }

        // Sanitize filename and add extension
        let sanitizedName = sanitizeFilename(name)
        let filename = sanitizedName.hasSuffix(".md") ? sanitizedName : "\(sanitizedName).md"
        let fileURL = targetURL.appendingPathComponent(filename)

        // Write the content
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Appends content to an existing note, or creates it if it doesn't exist
    func appendToNote(name: String, content: String, path: String = "") throws {
        guard let vaultURL = resolveBookmark() else {
            throw VaultError.noVaultSelected
        }

        guard vaultURL.startAccessingSecurityScopedResource() else {
            throw VaultError.accessDenied
        }

        defer {
            vaultURL.stopAccessingSecurityScopedResource()
        }

        var targetURL = vaultURL
        if !path.isEmpty {
            let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            targetURL = vaultURL.appendingPathComponent(cleanPath)
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        }

        let sanitizedName = sanitizeFilename(name)
        let filename = sanitizedName.hasSuffix(".md") ? sanitizedName : "\(sanitizedName).md"
        let fileURL = targetURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Append to existing file
            let existingContent = try String(contentsOf: fileURL, encoding: .utf8)
            let newContent = existingContent + "\n\n" + content
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            // Create new file
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Prepends content to an existing note, or creates it if it doesn't exist
    func prependToNote(name: String, content: String, path: String = "") throws {
        guard let vaultURL = resolveBookmark() else {
            throw VaultError.noVaultSelected
        }

        guard vaultURL.startAccessingSecurityScopedResource() else {
            throw VaultError.accessDenied
        }

        defer {
            vaultURL.stopAccessingSecurityScopedResource()
        }

        var targetURL = vaultURL
        if !path.isEmpty {
            let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            targetURL = vaultURL.appendingPathComponent(cleanPath)
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        }

        let sanitizedName = sanitizeFilename(name)
        let filename = sanitizedName.hasSuffix(".md") ? sanitizedName : "\(sanitizedName).md"
        let fileURL = targetURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Prepend to existing file
            let existingContent = try String(contentsOf: fileURL, encoding: .utf8)
            let newContent = content + "\n\n" + existingContent
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            // Create new file
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Gets the path to the daily note for today
    func getDailyNotePath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name
            .components(separatedBy: invalidChars)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum VaultError: LocalizedError {
    case noVaultSelected
    case accessDenied
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .noVaultSelected:
            return "No vault folder selected. Please select your Obsidian vault in Settings."
        case .accessDenied:
            return "Cannot access vault folder. Please re-select your vault in Settings."
        case .writeError(let message):
            return "Failed to write note: \(message)"
        }
    }
}
