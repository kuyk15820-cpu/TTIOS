import Foundation
import UIKit

final class AppLauncher {
    static func launchApp(bundleID: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else { return false }
        let selector = Selector(("defaultWorkspace"))
        guard workspaceClass.responds(to: selector) else { return false }
        
        let workspace = workspaceClass.perform(selector)?.takeUnretainedValue() as? NSObject
        let openSelector = Selector(("openApplicationWithBundleID:"))
        
        if let workspace = workspace, workspace.responds(to: openSelector) {
            typealias OpenAppImp = @convention(c) (AnyObject, Selector, NSString) -> Bool
            let method = workspace.method(for: openSelector)
            let imp = unsafeBitCast(method, to: OpenAppImp.self)
            return imp(workspace, openSelector, bundleID as NSString)
        }
        return false
    }
}

extension UIImage {
    static func applicationIcon(forBundleIdentifier bid: String) -> UIImage? {
        let selector = Selector(("_applicationIconImageForBundleIdentifier:format:scale:"))
        guard UIImage.responds(to: selector) else { return nil }

        typealias FunctionImp = @convention(c) (AnyObject, Selector, NSString, Int, CGFloat) -> Unmanaged<UIImage>?
        let method = UIImage.method(for: selector)
        let imp = unsafeBitCast(method, to: FunctionImp.self)

        let scale = UIScreen.main.scale
        if let unmanagedImage = imp(UIImage.self, selector, bid as NSString, 0, scale) {
            return unmanagedImage.takeUnretainedValue()
        }
        return nil
    }
}
