import SwiftUI

struct LLMConfigView: View {
    @StateObject private var storage = LLMProviderStorage.shared
    @State private var showingAddProvider = false
    @State private var selectedProvider: LLMProvider?

    var body: some View {
        List {
            if storage.providers.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No AI Providers")
                            .font(.headline)
                        Text("Add an AI provider to use {{prompt:...}} variables in your templates.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                ForEach(storage.providers) { provider in
                    Button {
                        selectedProvider = provider
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(provider.modelId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if provider.isDefault {
                                Text("Default")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteProviders)
            }
        }
        .navigationTitle("AI Providers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedProvider = nil
                    showingAddProvider = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            NavigationStack {
                LLMProviderEditorView(provider: nil) { provider in
                    storage.saveProvider(provider)
                }
            }
        }
        .sheet(item: $selectedProvider) { provider in
            NavigationStack {
                LLMProviderEditorView(provider: provider) { updated in
                    storage.saveProvider(updated)
                }
            }
        }
    }

    private func deleteProviders(at offsets: IndexSet) {
        for index in offsets {
            let provider = storage.providers[index]
            storage.deleteProvider(id: provider.id)
        }
    }
}

struct LLMProviderEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var providerId: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var modelId: String
    @State private var isDefault: Bool

    let provider: LLMProvider?
    let onSave: (LLMProvider) -> Void

    init(provider: LLMProvider?, onSave: @escaping (LLMProvider) -> Void) {
        self.provider = provider
        self.onSave = onSave

        _name = State(initialValue: provider?.name ?? "")
        _providerId = State(initialValue: provider?.providerId ?? "anthropic")
        _baseURL = State(initialValue: provider?.baseURL ?? "https://api.anthropic.com")
        _apiKey = State(initialValue: provider?.apiKey ?? "")
        _modelId = State(initialValue: provider?.modelId ?? "claude-sonnet-4-20250514")
        _isDefault = State(initialValue: provider?.isDefault ?? false)
    }

    var body: some View {
        Form {
            Section("Provider") {
                TextField("Name", text: $name)

                Picker("Provider Type", selection: $providerId) {
                    Text("Anthropic").tag("anthropic")
                    Text("OpenAI").tag("openai")
                    Text("Ollama").tag("ollama")
                    Text("OpenRouter").tag("openrouter")
                    Text("Custom").tag("custom")
                }
                .onChange(of: providerId) { _, newValue in
                    updateBaseURL(for: newValue)
                }
            }

            Section("API Settings") {
                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)

                TextField("Model ID", text: $modelId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Toggle("Use as Default", isOn: $isDefault)
            }
        }
        .navigationTitle(provider == nil ? "Add Provider" : "Edit Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProvider()
                }
                .disabled(name.isEmpty || apiKey.isEmpty)
            }
        }
    }

    private func updateBaseURL(for providerId: String) {
        switch providerId {
        case "anthropic":
            baseURL = "https://api.anthropic.com"
            modelId = "claude-sonnet-4-20250514"
        case "openai":
            baseURL = "https://api.openai.com"
            modelId = "gpt-4o"
        case "ollama":
            baseURL = "http://localhost:11434"
            modelId = "llama3"
        case "openrouter":
            baseURL = "https://openrouter.ai/api"
            modelId = "anthropic/claude-sonnet-4-20250514"
        default:
            break
        }
    }

    private func saveProvider() {
        let savedProvider = LLMProvider(
            id: provider?.id ?? UUID().uuidString,
            name: name,
            providerId: providerId,
            baseURL: baseURL,
            apiKey: apiKey,
            modelId: modelId,
            isDefault: isDefault
        )
        onSave(savedProvider)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        LLMConfigView()
    }
}
