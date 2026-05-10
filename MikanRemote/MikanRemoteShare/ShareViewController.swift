import UIKit

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Real implementation lands in Task 8.
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
