import SwiftUI

struct ClipperView: View {
    let extensionContext: NSExtensionContext?
    let dismiss: () -> Void

    @StateObject private var viewModel = ClipperViewModel()
    @State private var selectedTemplateId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Clip to Obsidian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Clip") {
                        clipContent()
                    }
                    .disabled(viewModel.isLoading || viewModel.preview.isEmpty)
                }
            }
            .task {
                await loadContent()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading page...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task {
                    await loadContent()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            // URL display
            if let url = viewModel.pageURL {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    Text(url.host ?? url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }

            // Template picker
            TemplatePickerView(
                selectedTemplateId: $selectedTemplateId,
                onSelectionChange: { templateId in
                    viewModel.renderPreview(withTemplateId: templateId)
                }
            )
            .padding()

            Divider()

            // Preview
            PreviewView(markdown: viewModel.preview)
        }
    }

    private func loadContent() async {
        guard let url = await ShareViewController.extractURL(from: extensionContext) else {
            viewModel.error = "Could not extract URL from shared content"
            return
        }

        await viewModel.loadPage(url: url)

        // Select default template
        if let defaultTemplate = TemplateStorage.shared.getDefaultTemplate() {
            selectedTemplateId = defaultTemplate.id
            viewModel.renderPreview(withTemplateId: defaultTemplate.id)
        }
    }

    private func clipContent() {
        guard let clipRequest = viewModel.createClipRequest(templateId: selectedTemplateId) else {
            return
        }

        // Store the clip request for the main app to process
        AppGroupManager.shared.setPendingClip(clipRequest)

        // Dismiss the extension
        dismiss()
    }
}

class ClipperViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var preview = ""
    @Published var pageURL: URL?

    private var clippingEngine: ClippingEngine?
    private var extractedVariables: ClipVariables?

    @MainActor
    func loadPage(url: URL) async {
        isLoading = true
        error = nil
        pageURL = url

        do {
            // Fetch HTML
            let html = try await HTMLFetcher.fetch(url: url)

            // Initialize clipping engine
            clippingEngine = ClippingEngine()
            try clippingEngine?.initialize()

            // Extract content
            extractedVariables = try clippingEngine?.extractContent(html: html, url: url.absoluteString)

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func renderPreview(withTemplateId templateId: String?) {
        guard let variables = extractedVariables,
              let engine = clippingEngine else {
            return
        }

        let template: Template?
        if let templateId = templateId {
            template = TemplateStorage.shared.getTemplate(byId: templateId)
        } else {
            template = TemplateStorage.shared.getDefaultTemplate()
        }

        guard let template = template else {
            // Use basic preview if no template
            preview = """
            # \(variables.title)

            \(variables.content)
            """
            return
        }

        do {
            preview = try engine.renderTemplate(template, with: variables)
        } catch {
            preview = "Error rendering template: \(error.localizedDescription)"
        }
    }

    func createClipRequest(templateId: String?) -> ClipRequest? {
        guard let variables = extractedVariables,
              let engine = clippingEngine else {
            return nil
        }

        let template = templateId.flatMap { TemplateStorage.shared.getTemplate(byId: $0) }
            ?? TemplateStorage.shared.getDefaultTemplate()

        var content: String
        var noteName: String
        let path: String
        let vault: String?
        let behavior: TemplateBehavior

        if let template = template {
            do {
                content = try engine.renderTemplate(template, with: variables)
                noteName = try engine.renderString(template.noteNameFormat, with: variables)
            } catch {
                content = variables.content
                noteName = variables.noteName
            }
            path = template.path
            vault = template.vault ?? SettingsManager.shared.defaultVault
            behavior = template.behavior
        } else {
            content = """
            # \(variables.title)

            \(variables.content)

            Source: \(variables.url)
            """
            noteName = variables.noteName
            path = ""
            vault = SettingsManager.shared.defaultVault
            behavior = .create
        }

        return ClipRequest(
            noteName: noteName,
            content: content,
            path: path,
            vault: vault.flatMap { $0.isEmpty ? nil : $0 },
            behavior: behavior
        )
    }
}
