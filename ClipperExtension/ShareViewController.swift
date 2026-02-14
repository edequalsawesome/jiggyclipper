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

// MARK: - URL Extraction

extension ShareViewController {
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
