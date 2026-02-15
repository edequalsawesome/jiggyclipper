import Foundation

struct Template: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var behavior: TemplateBehavior
    var noteNameFormat: String
    var path: String
    var noteContentFormat: String
    var properties: [TemplateProperty]
    var triggers: [String]?
    var vault: String?
    var context: String?
    var schemaVersion: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        behavior: TemplateBehavior = .create,
        noteNameFormat: String = "{{title}}",
        path: String = "",
        noteContentFormat: String = "{{content}}",
        properties: [TemplateProperty] = [],
        triggers: [String]? = nil,
        vault: String? = nil,
        context: String? = nil,
        schemaVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.behavior = behavior
        self.noteNameFormat = noteNameFormat
        self.path = path
        self.noteContentFormat = noteContentFormat
        self.properties = properties
        self.triggers = triggers
        self.vault = vault
        self.context = context
        self.schemaVersion = schemaVersion
    }

    // Custom decoder to handle browser extension format (no id field)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate ID if not present (browser extension format doesn't have it)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString

        self.name = try container.decode(String.self, forKey: .name)
        self.behavior = try container.decode(TemplateBehavior.self, forKey: .behavior)
        self.noteNameFormat = try container.decodeIfPresent(String.self, forKey: .noteNameFormat) ?? "{{title}}"
        self.path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        self.noteContentFormat = try container.decode(String.self, forKey: .noteContentFormat)
        self.properties = try container.decodeIfPresent([TemplateProperty].self, forKey: .properties) ?? []
        self.triggers = try container.decodeIfPresent([String].self, forKey: .triggers)
        self.vault = try container.decodeIfPresent(String.self, forKey: .vault)
        self.context = try container.decodeIfPresent(String.self, forKey: .context)
        self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, behavior, noteNameFormat, path, noteContentFormat
        case properties, triggers, vault, context, schemaVersion
    }
}

enum TemplateBehavior: String, Codable, CaseIterable {
    case create
    case appendSpecific = "append-specific"
    case appendDaily = "append-daily"
    case prependSpecific = "prepend-specific"
    case prependDaily = "prepend-daily"
    case overwrite

    var displayName: String {
        switch self {
        case .create: return "Create new note"
        case .appendSpecific: return "Append to specific note"
        case .appendDaily: return "Append to daily note"
        case .prependSpecific: return "Prepend to specific note"
        case .prependDaily: return "Prepend to daily note"
        case .overwrite: return "Overwrite existing note"
        }
    }
}

struct TemplateProperty: Codable, Identifiable, Equatable {
    var id: String?
    var name: String
    var value: String
    var type: PropertyType?

    enum PropertyType: String, Codable {
        case text
        case number
        case checkbox
        case date
        case datetime
        case multitext
    }
}
