import SwiftUI

@main
struct JiggyClipperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle callbacks or deep links if needed
        print("Received URL: \(url)")
    }
}

class AppState: ObservableObject {
    @Published var pendingClipURL: String?

    private let appGroupManager = AppGroupManager.shared

    init() {
        checkForPendingClips()
    }

    func checkForPendingClips() {
        if let pendingClip = appGroupManager.getPendingClip() {
            // Open Obsidian with the pending clip
            ObsidianLauncher.shared.openObsidian(with: pendingClip)
            appGroupManager.clearPendingClip()
        }
    }
}
