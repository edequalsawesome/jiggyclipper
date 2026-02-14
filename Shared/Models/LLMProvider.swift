import Foundation

struct LLMProvider: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var providerId: String
    var baseURL: String
    var apiKey: String
    var modelId: String
    var isDefault: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        providerId: String,
        baseURL: String,
        apiKey: String,
        modelId: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.providerId = providerId
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelId = modelId
        self.isDefault = isDefault
    }
}

class LLMProviderStorage: ObservableObject {
    static let shared = LLMProviderStorage()

    @Published var providers: [LLMProvider] = []

    private let appGroup = AppGroupManager.shared
    private let providersKey = "llmProviders"

    private init() {
        loadProviders()
    }

    func loadProviders() {
        guard let data = appGroup.getData(forKey: providersKey) else {
            providers = []
            return
        }

        do {
            providers = try JSONDecoder().decode([LLMProvider].self, from: data)
        } catch {
            print("Failed to decode providers: \(error)")
            providers = []
        }
    }

    func saveProvider(_ provider: LLMProvider) {
        var updatedProvider = provider

        // If this is set as default, unset others
        if provider.isDefault {
            providers = providers.map { p in
                var updated = p
                updated.isDefault = false
                return updated
            }
        }

        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = updatedProvider
        } else {
            // First provider is default
            if providers.isEmpty {
                updatedProvider.isDefault = true
            }
            providers.append(updatedProvider)
        }
        persistProviders()
    }

    func deleteProvider(id: String) {
        providers.removeAll { $0.id == id }
        persistProviders()
    }

    func getDefaultProvider() -> LLMProvider? {
        providers.first { $0.isDefault } ?? providers.first
    }

    private func persistProviders() {
        do {
            let data = try JSONEncoder().encode(providers)
            appGroup.setData(data, forKey: providersKey)
        } catch {
            print("Failed to encode providers: \(error)")
        }
    }
}
