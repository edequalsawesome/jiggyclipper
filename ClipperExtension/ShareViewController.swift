import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ClipperView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let clipperView = ClipperView(
            extensionContext: extensionContext,
            dismiss: { [weak self] in
                self?.dismissExtension()
            }
        )

        let hostingController = UIHostingController(rootView: clipperView)
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func dismissExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - Content Extraction

/// Result from Safari JavaScript preprocessing
struct PreprocessedContent {
    let url: URL
    let title: String
    let html: String
    let contentHtml: String
    let selectedHtml: String?
    let author: String?
    let description: String?
    let published: String?
    let image: String?
    let site: String?
}

extension ShareViewController {
    /// Extract preprocessed content from Safari (includes authenticated content)
    static func extractPreprocessedContent(from extensionContext: NSExtensionContext?) async -> PreprocessedContent? {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for inputItem in inputItems {
            guard let attachments = inputItem.attachments else { continue }

            for attachment in attachments {
                // Check for JavaScript preprocessing results
                if attachment.hasItemConformingToTypeIdentifier("com.apple.property-list") {
                    do {
                        let item = try await attachment.loadItem(forTypeIdentifier: "com.apple.property-list")
                        if let dict = item as? [String: Any],
                           let jsResults = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
                            return parsePreprocessedResults(jsResults)
                        }
                    } catch {
                        print("Failed to load preprocessed content: \(error)")
                    }
                }
            }
        }

        return nil
    }

    private static func parsePreprocessedResults(_ results: [String: Any]) -> PreprocessedContent? {
        guard let urlString = results["url"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }

        return PreprocessedContent(
            url: url,
            title: results["title"] as? String ?? "Untitled",
            html: results["html"] as? String ?? "",
            contentHtml: results["contentHtml"] as? String ?? "",
            selectedHtml: results["selectedHtml"] as? String,
            author: results["author"] as? String,
            description: results["description"] as? String,
            published: results["published"] as? String,
            image: results["image"] as? String,
            site: results["site"] as? String
        )
    }

    /// Fallback: Extract just the URL (for non-Safari shares)
    static func extractURL(from extensionContext: NSExtensionContext?) async -> URL? {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for inputItem in inputItems {
            guard let attachments = inputItem.attachments else { continue }

            for attachment in attachments {
                // Try URL first
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    do {
                        let item = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier)
                        if let url = item as? URL {
                            return url
                        }
                    } catch {
                        print("Failed to load URL: \(error)")
                    }
                }

                // Try plain text (might be a URL string)
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    do {
                        let item = try await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                        if let text = item as? String, let url = URL(string: text) {
                            return url
                        }
                    } catch {
                        print("Failed to load text: \(error)")
                    }
                }
            }
        }

        return nil
    }
}
