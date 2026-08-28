import Foundation
import UIKit
import SwiftUI

class AppUpdateStreamManager: NSObject, URLSessionDataDelegate {
    
    static let shared = AppUpdateStreamManager()
    
    typealias RealtimeUpdateHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var updateHandler: RealtimeUpdateHandler?
    private var isUpdatePresented: Bool = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Start Listening
    func startListening(handler: RealtimeUpdateHandler? = nil) {
        if let customHandler = handler {
            self.updateHandler = customHandler
        } else {
            self.updateHandler = { [weak self] needsUpdate, downloadUrl, releaseNotes, serverVersion in
                guard needsUpdate, let self = self, !self.isUpdatePresented else { return }
                self.presentUpdateUI(downloadUrl: downloadUrl, releaseNotes: releaseNotes, versionString: serverVersion)
            }
        }
        
        guard let url = URL(string: "https://f1x3r.org/pv/stream_app_version.php") else {
            self.showDebugAlert(title: "❌ URL Error", message: "ไม่สามารถเชื่อมต่อ URL ของ Stream ได้")
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        self.dataTask = self.session?.dataTask(with: url)
        self.dataTask?.resume()
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        self.dataTask?.cancel()
        self.session?.invalidateAndCancel()
    }
    
    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let responseString = String(data: data, encoding: .utf8) else { return }
        
        if responseString.contains("event: app_update") {
            let lines = responseString.components(separatedBy: "\n")
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    guard let jsonData = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
                        self.showDebugAlert(title: "❌ JSON Error", message: "แปลงข้อมูล JSON จาก Server ไม่สำเร็จ:\n\(jsonString)")
                        continue
                    }
                    
                    // 1. ดึงข้อมูลจริงจาก Info.plist
                    let currentBundleID = Bundle.main.bundleIdentifier ?? "N/A"
                    let currentAppName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
                                        ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "N/A"
                    let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "N/A"
                    
                    // 2. ดึงค่าจาก Server JSON
                    let serverBundleID = json["bundleID"] as? String ?? "N/A"
                    let serverAppName = json["appName"] as? String ?? "N/A"
                    let serverVersion = json["latestVersion"] as? String ?? "1.0.0"
                    let allowedVersions = json["allowedVersions"] as? [String] ?? []
                    let downloadUrl = json["downloadUrl"] as? String
                    let releaseNotes = json["releaseNotes"] as? String
                    
                    // 3. ตรวจสอบเงื่อนไขความปลอดภัย
                    let isBundleValid = (currentBundleID == serverBundleID)
                    let isAppNameValid = (currentAppName == "N/A") ? true : (currentAppName == serverAppName)
                    let isVersionAllowed = allowedVersions.contains(currentVersion)
                    
                    // สร้าง Log ข้อความสรุป
                    let logMessage = """
                    📱 [เครื่อง]
                    • BundleID: \(currentBundleID)
                    • AppName: \(currentAppName)
                    • Version: \(currentVersion)

                    🌐 [Server]
                    • BundleID: \(serverBundleID)
                    • AppName: \(serverAppName)
                    • Allowed Versions: \(allowedVersions.joined(separator: ", "))

                    ⚙️ [ผลการเช็ค]
                    • BundleID ตรงกัน: \(isBundleValid ? "✅" : "❌")
                    • AppName ตรงกัน: \(isAppNameValid ? "✅" : "❌")
                    • Version อนุญาต: \(isVersionAllowed ? "✅" : "❌")
                    """
                    
                    // 🚨 หากเงื่อนไขใดไม่ตรง ให้เด้ง Alert Log ขึ้นมาทันที
                    if !isBundleValid || !isAppNameValid || !isVersionAllowed {
                        DispatchQueue.main.async { [weak self] in
                            self?.showDebugAlert(title: "⚠️ ตรวจพบข้อมูลไม่ตรงกัน!", message: logMessage) {
                                // พอกด OK ใน Alert Log จะสั่งเปิดหน้า UI TestFlight ทันที
                                self?.updateHandler?(true, downloadUrl, releaseNotes, serverVersion)
                            }
                        }
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            self?.showDebugAlert(title: "✅ ข้อมูลถูกต้อง", message: logMessage)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Alert Log (แสดง Alert บนหน้าจอ)
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
    
    // MARK: - Safe Presentation Method (แสดง UI TestFlight)
    private func presentUpdateUI(downloadUrl: String?, releaseNotes: String?, versionString: String) {
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
    
    // หา Top-most ViewController
    private func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? {
            if #available(iOS 15.0, *) {
                return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.rootViewController
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
