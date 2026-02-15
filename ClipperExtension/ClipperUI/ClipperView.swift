import SwiftUI

struct ClipperView: View {
    let extensionContext: NSExtensionContext?
    let dismiss: () -> Void

    @StateObject private var viewModel = ClipperViewModel()
    @State private var selectedTemplateId: String?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

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
                    .disabled(viewModel.isLoading || viewModel.preview.isEmpty || !VaultManager.shared.hasVault)
                }
            }
            .task {
                await loadContent()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    if !VaultManager.shared.hasVault {
                        dismiss()
                    }
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Clipped!", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Note saved to your vault")
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
            // Vault status warning
            if !VaultManager.shared.hasVault {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Select a vault folder in the JiggyClipper app first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemYellow).opacity(0.2))
            }

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
        // Try Safari preprocessing first (runs in page context, gets authenticated content)
        if let preprocessed = await ShareViewController.extractPreprocessedContent(from: extensionContext),
           !preprocessed.contentHtml.isEmpty {
            // Safari preprocessing succeeded - use it
            await viewModel.loadFromPreprocessed(preprocessed)
        } else {
            // Fallback: fetch via URLSession
            guard let url = await ShareViewController.extractURL(from: extensionContext) else {
                viewModel.error = "Could not extract URL from shared content"
                return
            }
            await viewModel.loadPage(url: url)
        }

        // Select default template
        if let defaultTemplate = TemplateStorage.shared.getDefaultTemplate() {
            selectedTemplateId = defaultTemplate.id
            viewModel.renderPreview(withTemplateId: defaultTemplate.id)
        }
    }

    private func clipContent() {
        guard let clipRequest = viewModel.createClipRequest(templateId: selectedTemplateId) else {
            errorMessage = "Failed to create clip request"
            showingError = true
            return
        }

        // Write directly to vault
        do {
            switch clipRequest.behavior {
            case .create, .overwrite:
                try VaultManager.shared.writeNote(
                    name: clipRequest.noteName,
                    content: clipRequest.content,
                    path: clipRequest.path
                )

            case .appendSpecific:
                try VaultManager.shared.appendToNote(
                    name: clipRequest.noteName,
                    content: clipRequest.content,
                    path: clipRequest.path
                )

            case .prependSpecific:
                try VaultManager.shared.prependToNote(
                    name: clipRequest.noteName,
                    content: clipRequest.content,
                    path: clipRequest.path
                )

            case .appendDaily:
                let dailyPath = AppGroupManager.shared.getString(forKey: "dailyNotesPath") ?? ""
                let dailyName = VaultManager.shared.getDailyNotePath()
                try VaultManager.shared.appendToNote(
                    name: dailyName,
                    content: clipRequest.content,
                    path: dailyPath
                )

            case .prependDaily:
                let dailyPath = AppGroupManager.shared.getString(forKey: "dailyNotesPath") ?? ""
                let dailyName = VaultManager.shared.getDailyNotePath()
                try VaultManager.shared.prependToNote(
                    name: dailyName,
                    content: clipRequest.content,
                    path: dailyPath
                )
            }

            showingSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
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

    @MainActor
    func loadFromPreprocessed(_ content: PreprocessedContent) async {
        isLoading = true
        error = nil
        pageURL = content.url

        do {
            // Initialize clipping engine
            clippingEngine = ClippingEngine()
            try clippingEngine?.initialize()

            // Use preprocessed content directly - it already has the authenticated HTML
            let html = content.contentHtml.isEmpty ? content.html : content.contentHtml
            extractedVariables = try clippingEngine?.extractContent(html: html, url: content.url.absoluteString)

            // Override with preprocessed metadata if available
            if var variables = extractedVariables {
                if !content.title.isEmpty {
                    variables.title = content.title
                    variables.noteName = ClipVariables.sanitizeNoteName(content.title)
                }
                if let author = content.author, !author.isEmpty {
                    variables.author = author
                }
                if let description = content.description, !description.isEmpty {
                    variables.description = description
                }
                if let published = content.published, !published.isEmpty {
                    variables.published = published
                }
                if let image = content.image, !image.isEmpty {
                    variables.image = image
                }
                if let site = content.site, !site.isEmpty {
                    variables.site = site
                }
                extractedVariables = variables
            }

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
            vault = template.vault
            behavior = template.behavior
        } else {
            content = """
            # \(variables.title)

            \(variables.content)

            Source: \(variables.url)
            """
            noteName = variables.noteName
            path = ""
            vault = nil
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
