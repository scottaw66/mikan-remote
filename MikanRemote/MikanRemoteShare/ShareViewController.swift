import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await processInput() }
    }

    private func processInput() async {
        defer {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
        guard let url = await extractFirstURL() else { return }
        SharedDefaults.shared.pendingShareURL = url.absoluteString
        await openContainingApp()
    }

    private func extractFirstURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = obj as? URL {
                        return url
                    }
                }
            }
            // Fallback: parse URL out of plain text
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let text = obj as? String,
                       let detected = firstURL(in: text) {
                        return detected
                    }
                }
            }
        }
        return nil
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url
    }

    @MainActor
    private func openContainingApp() {
        guard let url = URL(string: "mikanremote://share") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
        // Responder-chain walk failed. URL is already in the App Group slot;
        // when the user manually returns to MikanRemote, scenePhase = .active
        // will trigger consumePending() and the URL will be sent.
    }
}
