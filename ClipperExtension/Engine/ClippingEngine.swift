import Foundation
import JavaScriptCore

enum ClippingEngineError: Error, LocalizedError {
    case initializationFailed
    case bundleNotFound
    case jsError(String)
    case extractionFailed
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize JavaScript engine"
        case .bundleNotFound:
            return "JavaScript bundle not found"
        case .jsError(let message):
            return "JavaScript error: \(message)"
        case .extractionFailed:
            return "Failed to extract content from page"
        case .renderingFailed:
            return "Failed to render template"
        }
    }
}

class ClippingEngine {
    private var context: JSContext?

    func initialize() throws {
        context = JSContext()

        guard let context = context else {
            throw ClippingEngineError.initializationFailed
        }

        // Set up error handling
        context.exceptionHandler = { _, exception in
            print("JS Exception: \(exception?.toString() ?? "unknown")")
        }

        // Set up console.log bridge
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JS] \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "consoleLog" as NSString)
        context.evaluateScript("var console = { log: consoleLog, error: consoleLog, warn: consoleLog };")

        // Load the JavaScript bundle
        try loadBundle()
    }

    private func loadBundle() throws {
        guard let bundleURL = Bundle.main.url(forResource: "clipper-core", withExtension: "js"),
              let bundleScript = try? String(contentsOf: bundleURL) else {
            // For now, use a placeholder implementation
            // TODO: Replace with actual bundled JS from obsidian-clipper
            try loadPlaceholderImplementation()
            return
        }

        context?.evaluateScript(bundleScript)
    }

    private func loadPlaceholderImplementation() throws {
        // Placeholder implementation until we bundle the real clipper JS
        let placeholderScript = """
        var ObsidianClipper = {
            extractContent: function(html, url) {
                // Basic content extraction
                var titleMatch = html.match(/<title[^>]*>([^<]+)<\\/title>/i);
                var title = titleMatch ? titleMatch[1].trim() : 'Untitled';

                // Extract meta description
                var descMatch = html.match(/<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["']/i);
                var description = descMatch ? descMatch[1] : '';

                // Extract author
                var authorMatch = html.match(/<meta[^>]*name=["']author["'][^>]*content=["']([^"']+)["']/i);
                var author = authorMatch ? authorMatch[1] : '';

                // Basic body extraction (strip scripts and styles)
                var bodyMatch = html.match(/<body[^>]*>([\\s\\S]*)<\\/body>/i);
                var bodyHtml = bodyMatch ? bodyMatch[1] : html;

                // Remove scripts and styles
                bodyHtml = bodyHtml.replace(/<script[\\s\\S]*?<\\/script>/gi, '');
                bodyHtml = bodyHtml.replace(/<style[\\s\\S]*?<\\/style>/gi, '');
                bodyHtml = bodyHtml.replace(/<nav[\\s\\S]*?<\\/nav>/gi, '');
                bodyHtml = bodyHtml.replace(/<footer[\\s\\S]*?<\\/footer>/gi, '');
                bodyHtml = bodyHtml.replace(/<header[\\s\\S]*?<\\/header>/gi, '');

                // Convert to basic markdown
                var content = this.htmlToMarkdown(bodyHtml);

                return {
                    title: title,
                    url: url,
                    content: content,
                    contentHtml: bodyHtml,
                    author: author,
                    description: description,
                    domain: new URL(url).hostname,
                    date: new Date().toISOString(),
                    time: new Date().toISOString(),
                    words: content.split(/\\s+/).length,
                    noteName: title.replace(/[\\\\/:*?"<>|]/g, '')
                };
            },

            htmlToMarkdown: function(html) {
                var md = html;

                // Headers
                md = md.replace(/<h1[^>]*>([\\s\\S]*?)<\\/h1>/gi, '\\n# $1\\n');
                md = md.replace(/<h2[^>]*>([\\s\\S]*?)<\\/h2>/gi, '\\n## $1\\n');
                md = md.replace(/<h3[^>]*>([\\s\\S]*?)<\\/h3>/gi, '\\n### $1\\n');
                md = md.replace(/<h4[^>]*>([\\s\\S]*?)<\\/h4>/gi, '\\n#### $1\\n');
                md = md.replace(/<h5[^>]*>([\\s\\S]*?)<\\/h5>/gi, '\\n##### $1\\n');
                md = md.replace(/<h6[^>]*>([\\s\\S]*?)<\\/h6>/gi, '\\n###### $1\\n');

                // Paragraphs
                md = md.replace(/<p[^>]*>([\\s\\S]*?)<\\/p>/gi, '\\n$1\\n');

                // Bold and italic
                md = md.replace(/<strong[^>]*>([\\s\\S]*?)<\\/strong>/gi, '**$1**');
                md = md.replace(/<b[^>]*>([\\s\\S]*?)<\\/b>/gi, '**$1**');
                md = md.replace(/<em[^>]*>([\\s\\S]*?)<\\/em>/gi, '*$1*');
                md = md.replace(/<i[^>]*>([\\s\\S]*?)<\\/i>/gi, '*$1*');

                // Links
                md = md.replace(/<a[^>]*href=["']([^"']+)["'][^>]*>([\\s\\S]*?)<\\/a>/gi, '[$2]($1)');

                // Images
                md = md.replace(/<img[^>]*src=["']([^"']+)["'][^>]*alt=["']([^"']*)["'][^>]*>/gi, '![$2]($1)');
                md = md.replace(/<img[^>]*alt=["']([^"']*)["'][^>]*src=["']([^"']+)["'][^>]*>/gi, '![$1]($2)');
                md = md.replace(/<img[^>]*src=["']([^"']+)["'][^>]*>/gi, '![]($1)');

                // Lists
                md = md.replace(/<li[^>]*>([\\s\\S]*?)<\\/li>/gi, '- $1\\n');
                md = md.replace(/<ul[^>]*>([\\s\\S]*?)<\\/ul>/gi, '$1');
                md = md.replace(/<ol[^>]*>([\\s\\S]*?)<\\/ol>/gi, '$1');

                // Blockquotes
                md = md.replace(/<blockquote[^>]*>([\\s\\S]*?)<\\/blockquote>/gi, '> $1\\n');

                // Code
                md = md.replace(/<code[^>]*>([\\s\\S]*?)<\\/code>/gi, '`$1`');
                md = md.replace(/<pre[^>]*>([\\s\\S]*?)<\\/pre>/gi, '```\\n$1\\n```\\n');

                // Line breaks
                md = md.replace(/<br\\s*\\/?>/gi, '\\n');
                md = md.replace(/<hr\\s*\\/?>/gi, '\\n---\\n');

                // Remove remaining HTML tags
                md = md.replace(/<[^>]+>/g, '');

                // Decode HTML entities
                md = md.replace(/&nbsp;/g, ' ');
                md = md.replace(/&amp;/g, '&');
                md = md.replace(/&lt;/g, '<');
                md = md.replace(/&gt;/g, '>');
                md = md.replace(/&quot;/g, '"');
                md = md.replace(/&#39;/g, "'");

                // Clean up whitespace
                md = md.replace(/\\n{3,}/g, '\\n\\n');
                md = md.trim();

                return md;
            },

            renderTemplate: function(templateContent, variables) {
                var result = templateContent;

                // Replace simple variables
                for (var key in variables) {
                    if (variables.hasOwnProperty(key)) {
                        var value = variables[key];
                        if (value === null || value === undefined) {
                            value = '';
                        } else if (typeof value === 'object') {
                            value = JSON.stringify(value);
                        }
                        var regex = new RegExp('\\\\{\\\\{' + key + '\\\\}\\\\}', 'g');
                        result = result.replace(regex, value);
                    }
                }

                // Handle date filter: {{var|date:"FORMAT"}}
                result = result.replace(/\\{\\{([^|]+)\\|\\s*date\\s*:\\s*"([^"]+)"\\}\\}/g, function(match, varName, format) {
                    var value = variables[varName.trim()];
                    if (value) {
                        try {
                            var date = new Date(value);
                            return formatDate(date, format);
                        } catch (e) {
                            return value;
                        }
                    }
                    return '';
                });

                // Clean up any remaining unresolved filter expressions
                result = result.replace(/\\{\\{[^}]+\\|[^}]+\\}\\}/g, '');

                return result;
            },

            formatDate: function(date, format) {
                var year = date.getFullYear();
                var month = String(date.getMonth() + 1).padStart(2, '0');
                var day = String(date.getDate()).padStart(2, '0');
                var hours = String(date.getHours()).padStart(2, '0');
                var minutes = String(date.getMinutes()).padStart(2, '0');
                var seconds = String(date.getSeconds()).padStart(2, '0');

                return format
                    .replace('YYYY', year)
                    .replace('MM', month)
                    .replace('DD', day)
                    .replace('HH', hours)
                    .replace('mm', minutes)
                    .replace('ss', seconds);
            },

            renderString: function(templateString, variables) {
                return this.renderTemplate(templateString, variables);
            }
        };
        """

        context?.evaluateScript(placeholderScript)
    }

    func extractContent(html: String, url: String) throws -> ClipVariables {
        guard let context = context else {
            throw ClippingEngineError.initializationFailed
        }

        // Pass HTML and URL to JavaScript safely
        context.setObject(html, forKeyedSubscript: "inputHtml" as NSString)
        context.setObject(url, forKeyedSubscript: "inputUrl" as NSString)

        let result = context.evaluateScript("ObsidianClipper.extractContent(inputHtml, inputUrl)")

        guard let dict = result?.toDictionary() as? [String: Any] else {
            throw ClippingEngineError.extractionFailed
        }

        return ClipVariables(
            title: dict["title"] as? String ?? "Untitled",
            url: dict["url"] as? String ?? url,
            content: dict["content"] as? String ?? "",
            contentHtml: dict["contentHtml"] as? String ?? html
        )
    }

    func renderTemplate(_ template: Template, with variables: ClipVariables) throws -> String {
        var output = ""

        // Render properties as YAML frontmatter if present
        if !template.properties.isEmpty {
            output += "---\n"
            for property in template.properties {
                // Skip LLM prompts (contain {{"  or {{\" or {{\")
                if property.value.contains("{{\"") || property.value.contains("{{\\\"") {
                    continue
                }

                let renderedValue = try renderString(property.value, with: variables)

                // Skip empty values or values that are just empty wikilinks/brackets
                let cleanedValue = renderedValue
                    .replacingOccurrences(of: "[[]]", with: "")
                    .replacingOccurrences(of: "[]", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if cleanedValue.isEmpty {
                    continue
                }

                // Format based on property type
                switch property.type {
                case .multitext:
                    // Multitext becomes a YAML array
                    let items = renderedValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let nonEmptyItems = items.filter { !$0.isEmpty && $0 != "[[]]" }
                    if nonEmptyItems.isEmpty {
                        continue
                    } else if nonEmptyItems.count == 1 {
                        output += "\(property.name): \(escapeYAMLValue(nonEmptyItems[0]))\n"
                    } else {
                        output += "\(property.name):\n"
                        for item in nonEmptyItems {
                            output += "  - \(escapeYAMLValue(item))\n"
                        }
                    }
                case .checkbox:
                    output += "\(property.name): \(renderedValue.lowercased() == "true")\n"
                default:
                    output += "\(property.name): \(escapeYAMLValue(renderedValue))\n"
                }
            }
            output += "---\n\n"
        }

        // Render the note content
        output += try renderString(template.noteContentFormat, with: variables)

        return output
    }

    private func escapeYAMLValue(_ value: String) -> String {
        // If value contains special characters, wrap in quotes
        let needsQuotes = value.contains(":") || value.contains("#") ||
                          value.contains("\"") || value.contains("'") ||
                          value.contains("\n") || value.hasPrefix(" ") ||
                          value.hasSuffix(" ") || value.hasPrefix("[") ||
                          value.hasPrefix("{")
        if needsQuotes {
            // Escape quotes and wrap
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return value
    }

    func renderString(_ templateString: String, with variables: ClipVariables) throws -> String {
        guard let context = context else {
            throw ClippingEngineError.initializationFailed
        }

        // Convert variables to dictionary for JS
        let variablesDict: [String: Any] = [
            "title": variables.title,
            "url": variables.url,
            "content": variables.content,
            "contentHtml": variables.contentHtml,
            "selection": variables.selection ?? "",
            "selectionHtml": variables.selectionHtml ?? "",
            "author": variables.author ?? "",
            "description": variables.description ?? "",
            "domain": variables.domain,
            "favicon": variables.favicon ?? "",
            "image": variables.image ?? "",
            "site": variables.site ?? "",
            "date": variables.date,
            "time": variables.time,
            "published": variables.published ?? "",
            "words": variables.words,
            "noteName": variables.noteName,
            "fullHtml": variables.fullHtml ?? ""
        ]

        context.setObject(templateString, forKeyedSubscript: "templateInput" as NSString)
        context.setObject(variablesDict, forKeyedSubscript: "variablesInput" as NSString)

        let result = context.evaluateScript("ObsidianClipper.renderString(templateInput, variablesInput)")

        guard let rendered = result?.toString() else {
            throw ClippingEngineError.renderingFailed
        }

        return rendered
    }
}
