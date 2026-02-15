import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var vaultName: String? = VaultManager.shared.vaultName
    @State private var showingFolderPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    @AppStorage("dailyNotesPath", store: AppGroupManager.shared.userDefaults)
    private var dailyNotesPath: String = ""

    @AppStorage("autoClip", store: AppGroupManager.shared.userDefaults)
    private var autoClip: Bool = false

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vault Folder")
                            .font(.body)
                        if let name = vaultName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not selected")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Button(vaultName == nil ? "Select" : "Change") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Obsidian Vault")
            } footer: {
                Text("Select your Obsidian vault folder to enable direct file saving")
            }

            Section {
                TextField("Daily Notes Path", text: $dailyNotesPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Daily Notes")
            } footer: {
                Text("Path to daily notes folder within your vault (e.g., \"Daily\" or \"Journal/Daily\")")
            }

            Section {
                Toggle("Auto-clip without preview", isOn: $autoClip)
            } header: {
                Text("Behavior")
            } footer: {
                Text("When enabled, clips will be sent directly using the default template")
            }

            if vaultName != nil {
                Section {
                    Button("Test Write Access") {
                        testWriteAccess()
                    }

                    Button("Clear Vault Selection", role: .destructive) {
                        VaultManager.shared.clearVault()
                        vaultName = nil
                    }
                } header: {
                    Text("Vault Access")
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView { url in
                do {
                    try VaultManager.shared.saveVaultBookmark(for: url)
                    vaultName = VaultManager.shared.vaultName
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func testWriteAccess() {
        do {
            try VaultManager.shared.writeNote(
                name: ".jiggyclipper-test",
                content: "Test file created by JiggyClipper. You can delete this."
            )
            errorMessage = "Write access verified successfully."
            showingError = true
        } catch {
            errorMessage = "Write test failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct FolderPickerView: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void

        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onSelect(url)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
