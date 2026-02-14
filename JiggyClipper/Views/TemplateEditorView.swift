import SwiftUI

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var behavior: TemplateBehavior
    @State private var noteNameFormat: String
    @State private var path: String
    @State private var noteContentFormat: String
    @State private var vault: String

    let template: Template?
    let onSave: (Template) -> Void

    init(template: Template?, onSave: @escaping (Template) -> Void) {
        self.template = template
        self.onSave = onSave

        _name = State(initialValue: template?.name ?? "New Template")
        _behavior = State(initialValue: template?.behavior ?? .create)
        _noteNameFormat = State(initialValue: template?.noteNameFormat ?? "{{title}}")
        _path = State(initialValue: template?.path ?? "")
        _noteContentFormat = State(initialValue: template?.noteContentFormat ?? defaultTemplateContent)
        _vault = State(initialValue: template?.vault ?? "")
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Template Name", text: $name)

                Picker("Behavior", selection: $behavior) {
                    ForEach(TemplateBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }

                TextField("Vault (optional)", text: $vault)
                    .textInputAutocapitalization(.never)
            }

            Section("Note Settings") {
                TextField("Note Name", text: $noteNameFormat)
                    .font(.system(.body, design: .monospaced))

                TextField("Folder Path", text: $path)
                    .textInputAutocapitalization(.never)
            }

            Section {
                TextEditor(text: $noteContentFormat)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
            } header: {
                Text("Note Content")
            } footer: {
                Text("Use {{variables}} and filters like {{title | upper}}")
            }

            Section("Available Variables") {
                DisclosureGroup("Show Variables") {
                    VStack(alignment: .leading, spacing: 8) {
                        variableRow("{{title}}", "Page title")
                        variableRow("{{url}}", "Page URL")
                        variableRow("{{content}}", "Article content (Markdown)")
                        variableRow("{{author}}", "Author name")
                        variableRow("{{description}}", "Meta description")
                        variableRow("{{date}}", "Current date")
                        variableRow("{{published}}", "Published date")
                        variableRow("{{domain}}", "Website domain")
                        variableRow("{{highlights}}", "Captured highlights")
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .navigationTitle(template == nil ? "New Template" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveTemplate()
                }
                .disabled(name.isEmpty)
            }
        }
    }

    private func variableRow(_ variable: String, _ description: String) -> some View {
        HStack {
            Text(variable)
                .foregroundStyle(.blue)
            Spacer()
            Text(description)
                .foregroundStyle(.secondary)
        }
    }

    private func saveTemplate() {
        let savedTemplate = Template(
            id: template?.id ?? UUID().uuidString,
            name: name,
            behavior: behavior,
            noteNameFormat: noteNameFormat,
            path: path,
            noteContentFormat: noteContentFormat,
            properties: template?.properties ?? [],
            vault: vault.isEmpty ? nil : vault
        )
        onSave(savedTemplate)
        dismiss()
    }
}

private let defaultTemplateContent = """
---
source: "{{url}}"
author: "{{author}}"
published: {{published}}
created: {{date}}
tags:
  - clippings
---

# {{title}}

{{content}}
"""

#Preview {
    NavigationStack {
        TemplateEditorView(template: nil) { _ in }
    }
}
