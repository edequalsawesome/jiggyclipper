import Foundation
import UIKit

class ObsidianLauncher {
    static let shared = ObsidianLauncher()

    private init() {}

    /// Opens Obsidian app
    func openObsidian() {
        guard let url = URL(string: "obsidian://") else { return }
        openURL(url)
    }

    /// Opens Obsidian with a new note
    func openObsidian(with clipRequest: ClipRequest) {
        var components = URLComponents()
        components.scheme = "obsidian"

        // Determine path based on behavior
        switch clipRequest.behavior {
        case .appendDaily, .prependDaily:
            components.host = "daily"
        default:
            components.host = "new"
        }

        var queryItems: [URLQueryItem] = []

        // Add vault if specified
        if let vault = clipRequest.vault, !vault.isEmpty {
            queryItems.append(URLQueryItem(name: "vault", value: vault))
        }

        // Add file path
        var filePath = clipRequest.path
        if !filePath.isEmpty && !filePath.hasSuffix("/") {
            filePath += "/"
        }
        filePath += clipRequest.noteName

        if components.host != "daily" {
            queryItems.append(URLQueryItem(name: "file", value: filePath))
        }

        // Handle content - prefer clipboard for large content
        let content = clipRequest.content
        if content.count > 2000 {
            // Use clipboard method
            UIPasteboard.general.string = content
            queryItems.append(URLQueryItem(name: "clipboard", value: ""))
        } else {
            queryItems.append(URLQueryItem(name: "content", value: content))
        }

        // Add behavior-specific parameters
        switch clipRequest.behavior {
        case .appendSpecific, .appendDaily:
            queryItems.append(URLQueryItem(name: "append", value: "true"))
        case .prependSpecific, .prependDaily:
            queryItems.append(URLQueryItem(name: "prepend", value: "true"))
        case .overwrite:
            queryItems.append(URLQueryItem(name: "overwrite", value: "true"))
        case .create:
            break
        }

        // Silent mode
        queryItems.append(URLQueryItem(name: "silent", value: "true"))

        components.queryItems = queryItems

        guard let url = components.url else {
            print("Failed to construct Obsidian URL")
            return
        }

        openURL(url)
    }

    private func openURL(_ url: URL) {
        DispatchQueue.main.async {
            UIApplication.shared.open(url) { success in
                if !success {
                    print("Failed to open URL: \(url)")
                }
            }
        }
    }
}
