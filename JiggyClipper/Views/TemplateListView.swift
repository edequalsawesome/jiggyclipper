import SwiftUI

struct TemplateListView: View {
    @StateObject private var templateStorage = TemplateStorage.shared
    @State private var showingImportSheet = false
    @State private var importText = ""
    @State private var showingEditor = false
    @State private var selectedTemplate: Template?

    var body: some View {
        List {
            if templateStorage.templates.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Templates")
                            .font(.headline)
                        Text("Import templates from the Obsidian Web Clipper extension or create new ones.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                ForEach(templateStorage.templates) { template in
                    Button {
                        selectedTemplate = template
                        showingEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(template.behavior.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("Import JSON", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        selectedTemplate = nil
                        showingEditor = true
                    } label: {
                        Label("Create New", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportTemplateView(importText: $importText) { jsonString in
                importTemplate(from: jsonString)
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                TemplateEditorView(template: selectedTemplate) { savedTemplate in
                    templateStorage.saveTemplate(savedTemplate)
                }
            }
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            let template = templateStorage.templates[index]
            templateStorage.deleteTemplate(id: template.id)
        }
    }

    private func importTemplate(from jsonString: String) {
        do {
            let template = try JSONDecoder().decode(Template.self, from: Data(jsonString.utf8))
            templateStorage.saveTemplate(template)
            showingImportSheet = false
            importText = ""
        } catch {
            // TODO: Show error alert
            print("Failed to import template: \(error)")
        }
    }
}

struct ImportTemplateView: View {
    @Binding var importText: String
    @Environment(\.dismiss) private var dismiss
    let onImport: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                Text("Paste the template JSON from your browser extension:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()

                TextEditor(text: $importText)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
            }
            .navigationTitle("Import Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(importText)
                    }
                    .disabled(importText.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TemplateListView()
    }
}
