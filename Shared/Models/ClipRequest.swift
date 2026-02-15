import Foundation

/// Represents a request to create a clip in Obsidian
struct ClipRequest: Codable {
    let noteName: String
    let content: String
    let path: String
    let vault: String?
    let behavior: TemplateBehavior
    let properties: [String: String]

    init(
        noteName: String,
        content: String,
        path: String = "",
        vault: String? = nil,
        behavior: TemplateBehavior = .create,
        properties: [String: String] = [:]
    ) {
        self.noteName = noteName
        self.content = content
        self.path = path
        self.vault = vault
        self.behavior = behavior
        self.properties = properties
    }
}

/// Variables available for template rendering
struct ClipVariables: Codable {
    var title: String
    var url: String
    var content: String
    var contentHtml: String
    var selection: String?
    var selectionHtml: String?
    var author: String?
    var description: String?
    var domain: String
    var favicon: String?
    var image: String?
    var site: String?
    var date: String
    var time: String
    var published: String?
    var words: Int
    var noteName: String
    var fullHtml: String?
    var highlights: [HighlightData]?
    var meta: [String: String]
    var schema: [String: Any]?

    init(
        title: String,
        url: String,
        content: String,
        contentHtml: String
    ) {
        self.title = title
        self.url = url
        self.content = content
        self.contentHtml = contentHtml
        self.domain = URL(string: url)?.host ?? ""
        // Use local timezone for date/time
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.timeZone = .current
        self.date = dateFormatter.string(from: now)
        self.time = self.date
        self.words = content.split(separator: " ").count
        self.noteName = Self.sanitizeNoteName(title)
        self.meta = [:]
    }

    static func sanitizeNoteName(_ name: String) -> String {
        // Remove characters not allowed in filenames
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name
            .components(separatedBy: invalidChars)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Custom encoding to handle schema (Any type)
    enum CodingKeys: String, CodingKey {
        case title, url, content, contentHtml, selection, selectionHtml
        case author, description, domain, favicon, image, site
        case date, time, published, words, noteName, fullHtml
        case highlights, meta
    }
}

struct HighlightData: Codable {
    let type: String
    let id: String
    let content: String
    var notes: [String]?
}
