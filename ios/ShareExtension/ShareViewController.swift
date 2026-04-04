import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    // The share_handler plugin reads from this App Group
    let sharedKey = "ShareKey"
    let appGroupId = "group.com.ministryoftruth.share"
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        if let content = extensionContext?.inputItems as? [NSExtensionItem] {
            for item in content {
                if let attachments = item.attachments {
                    for provider in attachments {
                        // Handle images
                        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, error) in
                                if let url = data as? URL {
                                    self.saveToSharedContainer(url: url)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func saveToSharedContainer(url: URL) {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }
        userDefaults.set(url.absoluteString, forKey: sharedKey)
        userDefaults.synchronize()
        
        // Open the main app
        if let appUrl = URL(string: "ministryoftruth://shared-media") {
            var responder: UIResponder? = self
            while let nextResponder = responder?.next {
                if let application = nextResponder as? UIApplication {
                    application.open(appUrl, options: [:], completionHandler: nil)
                    break
                }
                responder = nextResponder
            }
        }
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
}
