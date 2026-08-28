import Foundation
import UIKit
import SwiftUI

class AppUpdateCheckerManager {
    
    static let shared = AppUpdateCheckerManager()
    
    typealias UpdateCheckHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var updateHandler: UpdateCheckHandler?
    private var isUpdatePresented: Bool = false
    
    private init() {}
    
    // MARK: - Start Checking Version
    func checkVersion(handler: UpdateCheckHandler? = nil) {
        if let customHandler = handler {
            self.updateHandler = customHandler
        } else {
            self.updateHandler = { [weak self] needsUpdate, downloadUrl, releaseNotes, serverVersion in
                guard needsUpdate, let self = self, !self.isUpdatePresented else { return }
                self.presentUpdateUI(downloadUrl: downloadUrl, releaseNotes: releaseNotes, versionString: serverVersion)
            }
        }
        
        // ชี้ไปที่ไฟล์ PHP บนเซิร์ฟเวอร์ของคุณ
        guard let url = URL(string: "https://f1x3r.org/pv/app_version.php") else {
            self.showDebugAlert(title: "❌ URL Error", message: "ไม่สามารถสร้าง URL ได้")
            return
        }
        
        // กำหนด Standard HTTP GET Request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ [HTTP Error]: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("⚠️ [JSON Error]: ไม่สามารถอ่านข้อมูล JSON จาก PHP Server ได้")
                return
            }
            
            // 1. ดึงข้อมูลเครื่อง
            let currentBundleID = Bundle.main.bundleIdentifier ?? "N/A"
            let currentAppName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
                                ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "N/A"
            let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "N/A"
            
            // 2. ดึงข้อมูล Server
            let serverBundleID = json["bundleID"] as? String ?? "N/A"
            let serverAppName = json["appName"] as? String ?? "N/A"
            let serverVersion = json["latestVersion"] as? String ?? "1.0.0"
            let allowedVersions = json["allowedVersions"] as? [String] ?? []
            let downloadUrl = json["downloadUrl"] as? String
            let releaseNotes = json["releaseNotes"] as? String
            
            // 3. ตรวจสอบเงื่อนไข
            let isBundleValid = (currentBundleID == serverBundleID)
            let isAppNameValid = (currentAppName == "N/A") ? true : (currentAppName == serverAppName)
            let isVersionAllowed = allowedVersions.contains(currentVersion)
            
            let alertMessage = """
            📱 [เครื่อง]
            • BundleID: \(currentBundleID)
            • AppName: \(currentAppName)
            • Version: \(currentVersion)

            🌐 [Server JSON]
            • BundleID: \(serverBundleID)
            • AppName: \(serverAppName)
            • Allowed Versions: \(allowedVersions.joined(separator: ", "))

            ⚙️ [ผลลัพธ์]
            • BundleID ตรง: \(isBundleValid ? "✅" : "❌")
            • AppName ตรง: \(isAppNameValid ? "✅" : "❌")
            • Version ตรง: \(isVersionAllowed ? "✅" : "❌")
            """
            
            // เด้ง Alert Log ขึ้นจอ
            if !isBundleValid || !isAppNameValid || !isVersionAllowed {
                self.showDebugAlert(title: "⚠️ ตรวจพบข้อมูลไม่ตรงกัน!", message: alertMessage) {
                    self.updateHandler?(true, downloadUrl, releaseNotes, serverVersion)
                }
            } else {
                self.showDebugAlert(title: "✅ ข้อมูลตรงกันทั้งหมด", message: alertMessage)
            }
        }.resume()
    }
    
    // MARK: - Safe Alert & Present Method
    private func showDebugAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ตกลง (OK)", style: .default, handler: { _ in
                completion?()
            }))
            
            if let topVC = self.getTopViewController() {
                topVC.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func presentUpdateUI(downloadUrl: String?, releaseNotes: String?, versionString: String) {
        DispatchQueue.main.async {
            guard !self.isUpdatePresented else { return }
            self.isUpdatePresented = true
            
            let updateView = AppUpdateView(
                downloadUrl: downloadUrl,
                releaseNotes: releaseNotes,
                versionString: versionString
            )
            
            let hostingController = UIHostingController(rootView: updateView)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.isModalInPresentation = true
            
            if let topVC = self.getTopViewController() {
                topVC.present(hostingController, animated: true, completion: nil)
            }
        }
    }
    
    private func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? {
            if #available(iOS 15.0, *) {
                return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            } else {
                return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            }
        }()
        
        if let nav = baseVC as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController {
            if let selected = tab.selectedViewController {
                return getTopViewController(base: selected)
            }
        }
        if let presented = baseVC?.presentedViewController {
            return getTopViewController(base: presented)
        }
        return baseVC
    }
}
