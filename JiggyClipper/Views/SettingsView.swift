import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultVault", store: AppGroupManager.shared.userDefaults)
    private var defaultVault: String = ""

    @AppStorage("defaultTemplate", store: AppGroupManager.shared.userDefaults)
    private var defaultTemplate: String = ""

    @AppStorage("autoClip", store: AppGroupManager.shared.userDefaults)
    private var autoClip: Bool = false

    @State private var showingVaultHelp = false

    var body: some View {
        Form {
            Section {
                TextField("Vault Name", text: $defaultVault)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Default Vault")
            } footer: {
                Text("The name of your Obsidian vault (case-sensitive)")
            }

            Section {
                Toggle("Auto-clip without preview", isOn: $autoClip)
            } header: {
                Text("Behavior")
            } footer: {
                Text("When enabled, clips will be sent directly to Obsidian using the default template")
            }

            Section {
                Button("Open Obsidian") {
                    ObsidianLauncher.shared.openObsidian()
                }

                Button("Test Connection") {
                    testObsidianConnection()
                }
            } header: {
                Text("Obsidian")
            }
        }
        .navigationTitle("Settings")
    }

    private func testObsidianConnection() {
        // Try to open Obsidian to verify it's installed
        ObsidianLauncher.shared.openObsidian()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
