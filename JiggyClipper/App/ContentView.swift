import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }

                    NavigationLink {
                        TemplateListView()
                    } label: {
                        Label("Templates", systemImage: "doc.text")
                    }

                    NavigationLink {
                        LLMConfigView()
                    } label: {
                        Label("AI Providers", systemImage: "cpu")
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Use the Share button in Safari to clip web pages to Obsidian.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("JiggyClipper")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
