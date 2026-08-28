import Foundation
import UIKit
import SwiftUI

class AppUpdateStreamManager: NSObject, URLSessionDataDelegate {
    
    // Singleton Instance
    static let shared = AppUpdateStreamManager()
    
    typealias RealtimeUpdateHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var updateHandler: RealtimeUpdateHandler?
    private var isUpdatePresented: Bool = false // ป้องกันการเปิด Alert/UI ซ้ำ
    
    private override init() {
        super.init()
    }
    
    // MARK: - Start Listening (เริ่มฟัง Real-time Stream จาก Server)
    func startListening(handler: RealtimeUpdateHandler? = nil) {
        if let customHandler = handler {
            self.updateHandler = customHandler
        } else {
            // Default Handler: สั่งเปิด AppUpdateView (UI สไตล์ TestFlight) อัตโนมัติ
            self.updateHandler = { [weak self] needsUpdate, downloadUrl, releaseNotes, serverVersion in
                guard needsUpdate, let self = self, !self.isUpdatePresented else { return }
                self.presentUpdateUI(downloadUrl: downloadUrl, releaseNotes: releaseNotes, versionString: serverVersion)
            }
        }
        
        // URL ของ SSE Stream บน PHP Server
        guard let url = URL(string: "https://f1x3r.org/pv/stream_app_version.php") else { return }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0  // เปิด Connection ค้างไว้แบบคายท่อ Real-time
        config.timeoutIntervalForResource = 0
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        self.dataTask = self.session?.dataTask(with: url)
        self.dataTask?.resume()
    }
    
    // MARK: - Stop Listening (หยุดฟัง Stream)
    func stopListening() {
        self.dataTask?.cancel()
        self.session?.invalidateAndCancel()
    }
    
    // MARK: - URLSessionDataDelegate (รับข้อมูล Real-time จาก SSE)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let responseString = String(data: data, encoding: .utf8) else { return }
        
        // ตรวจหา event: app_update ที่ส่งมาจาก stream_app_version.php
        if responseString.contains("event: app_update") {
            let lines = responseString.components(separatedBy: "\n")
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    guard let jsonData = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
                        continue
                    }
                    
                    // 1. ดึงข้อมูลจริงจาก Info.plist ของเครื่องปัจจุบัน
                    let currentBundleID = Bundle.main.bundleIdentifier ?? ""
                    let currentAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String 
                                        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
                    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    
                    // 2. ดึงค่ากำหนดจาก Server JSON
                    let serverBundleID = json["bundleID"] as? String ?? ""
                    let serverAppName = json["appName"] as? String ?? ""
                    let serverVersion = json["latestVersion"] as? String ?? "1.0.0"
                    let allowedVersions = json["allowedVersions"] as? [String] ?? []
                    let downloadUrl = json["downloadUrl"] as? String
                    let releaseNotes = json["releaseNotes"] as? String
                    
                    // 3. ตรวจสอบเงื่อนไขความปลอดภัย 3 ชั้น
                    let isBundleValid = (currentBundleID == serverBundleID)
                    let isAppNameValid = (currentAppName == serverAppName)
                    let isVersionAllowed = allowedVersions.contains(currentVersion)
                    
                    // 🚨 หากเงื่อนไขใดไม่ตรง (โดนเปลี่ยน Bundle ID, เปลี่ยนชื่อแอป หรือแอบแก้ Info.plist)
                    if !isBundleValid || !isAppNameValid || !isVersionAllowed {
                        DispatchQueue.main.async { [weak self] in
                            self?.updateHandler?(true, downloadUrl, releaseNotes, serverVersion)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Presentation Method (สั่งแสดง UI แบบ Full Screen)
    private func presentUpdateUI(downloadUrl: String?, releaseNotes: String?, versionString: String) {
        self.isUpdatePresented = true
        
        let updateView = AppUpdateView(
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            versionString: versionString
        )
        
        let hostingController = UIHostingController(rootView: updateView)
        hostingController.modalPresentationStyle = .fullScreen
        hostingController.isModalInPresentation = true // ป้องกันการรูดลงเพื่อปิด
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            topVC.present(hostingController, animated: true)
        }
    }
}
