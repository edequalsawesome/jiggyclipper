import Foundation
import Combine

class TemplateStorage: ObservableObject {
    static let shared = TemplateStorage()

    @Published var templates: [Template] = []

    private let appGroup = AppGroupManager.shared
    private let templatesKey = "templates"

    private init() {
        loadTemplates()
    }

    /// Reload templates from storage - call this when extension activates
    func refresh() {
        loadTemplates()
    }

    func loadTemplates() {
        guard let data = appGroup.getData(forKey: templatesKey) else {
            templates = []
            return
        }

        do {
            templates = try JSONDecoder().decode([Template].self, from: data)
        } catch {
            print("Failed to decode templates: \(error)")
            templates = []
        }
    }

    func saveTemplate(_ template: Template) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        persistTemplates()
    }

    func deleteTemplate(id: String) {
        templates.removeAll { $0.id == id }
        persistTemplates()
    }

    func getTemplate(byId id: String) -> Template? {
        templates.first { $0.id == id }
    }

    func getDefaultTemplate() -> Template? {
        // Return first template as default, or nil
        templates.first
    }

    private func persistTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            appGroup.setData(data, forKey: templatesKey)
        } catch {
            print("Failed to encode templates: \(error)")
        }
    }
}
