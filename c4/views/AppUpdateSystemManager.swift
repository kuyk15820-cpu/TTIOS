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
    private var receivedBuffer = ""
    
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
            self.showDebugAlert(title: "❌ URL Error", message: "ไม่สามารถสร้าง URL ได้")
            return
        }
        
        // กำหนด Request Header สำหรับ Server-Sent Events (SSE)
        var request = URLRequest(url: url)
        request.timeoutInterval = Double.infinity
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        config.timeoutIntervalForResource = TimeInterval(INT_MAX)
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.dataTask = self.session?.dataTask(with: request)
        self.dataTask?.resume()
    }
    
    func stopListening() {
        self.dataTask?.cancel()
        self.session?.invalidateAndCancel()
    }
    
    // MARK: - URLSessionDataDelegate (ดักจับ Streaming Response)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // บังคับเปิดท่อ Stream ให้รับ data เรื่อยๆ
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        receivedBuffer += chunk
        
        // แยก Event ตาม SSE Standard (\n\n)
        let events = receivedBuffer.components(separatedBy: "\n\n")
        receivedBuffer = events.last ?? ""
        
        for event in events.dropLast() {
            parseSSEEvent(event)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.showDebugAlert(title: "❌ Stream Complete Error", message: error.localizedDescription)
        }
    }
    
    // MARK: - Parse SSE Event Data
    private func parseSSEEvent(_ eventString: String) {
        let lines = eventString.components(separatedBy: "\n")
        var dataString = ""
        
        for line in lines {
            if line.hasPrefix("data:") {
                let index = line.index(line.startIndex, offsetBy: 5)
                dataString += line[index...].trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard !dataString.isEmpty,
              let jsonData = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
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
