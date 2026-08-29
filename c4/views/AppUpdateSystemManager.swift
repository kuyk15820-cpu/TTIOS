import Foundation
import UIKit
import SwiftUI

// MARK: - AppUpdateCheckerManager
class AppUpdateCheckerManager: ObservableObject { // ปรับเป็น ObservableObject เพื่อให้ View สังเกตสถานะได้
    
    static let shared = AppUpdateCheckerManager()
    
    typealias UpdateCheckHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var updateHandler: UpdateCheckHandler?
    private var isUpdatePresented: Bool = false
    
    // MARK: - Download States (สำหรับ UI)
    @Published var isDownloading = false
    @Published var isDownloaded = false
    @Published var downloadProgress: Double = 0.0
    @Published var currentDownloadFileURL: URL?
    
    // MARK: - Private Configuration
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: DownloadProgressDelegate.shared, delegateQueue: nil)
    }()
    
    private init() {}
    
    // MARK: - Start Checking Version (Logic เดิม)
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
            
            // ตรวจสอบเงื่อนไขการอัปเดตและเรียกใช้งาน updateHandler โดยตรงโดยไม่ต้องแสดง Alert ก่อน
            if !isBundleValid || !isAppNameValid || !isVersionAllowed {
                self.updateHandler?(true, downloadUrl, releaseNotes, serverVersion)
            } else {
                self.updateHandler?(false, downloadUrl, releaseNotes, serverVersion)
            }
        }.resume()
    }
    
    // MARK: - File & Download Logic (ปรับปรุง)
    
    /// หา URL ของโฟลเดอร์ Application Support/.download/
    private func getDownloadDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        
        let downloadURL = appSupportURL.appendingPathComponent(".download", isDirectory: true)
        
        // สร้างโฟลเดอร์ถ้ายังไม่มี
        if !fileManager.fileExists(atPath: downloadURL.path) {
            try fileManager.createDirectory(at: downloadURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return downloadURL
    }
    
    /// ลบไฟล์ที่ดาวน์โหลดมา (Clean up)
    private func deleteDownloadedFile(at fileURL: URL) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
                print("✅ [File Deleted]: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ [Delete File Error]: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Download Action
    
    /// เริ่มดาวน์โหลดไฟล์แอปมาไว้ที่เครื่อง
    func startDownload(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // อัปเดต UI State บน Main Thread
        DispatchQueue.main.async {
            self.isDownloading = true
            self.isDownloaded = false
            self.downloadProgress = 0.0
            self.currentDownloadFileURL = nil
        }
        
        // ยกเลิก Task เก่า (ถ้ามี)
        downloadTask?.cancel()
        
        // สร้าง Download Task
        downloadTask = urlSession.downloadTask(with: url) { [weak self] (tempURL, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [Download Error]: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = false
                }
                // คุณอาจจะเพิ่ม showDebugAlert เพื่อบอก user
                return
            }
            
            guard let tempURL = tempURL,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ [Download Response Error]: Invalid server response")
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = false
                }
                return
            }
            
            do {
                let fileManager = FileManager.default
                
                // 1. เตรียมโฟลเดอร์ปลายทาง
                let downloadDir = try self.getDownloadDirectoryURL()
                
                // ดึงชื่อไฟล์จาก URL (ถ้ามี) หรือใช้ชื่อ Temporary
                let suggestedFilename = response?.suggestedFilename ?? url.lastPathComponent
                let finalFileURL = downloadDir.appendingPathComponent(suggestedFilename)
                
                // 2. ถ้ามีไฟล์เดิมอยู่ที่ปลายทางให้ลบก่อน
                if fileManager.fileExists(atPath: finalFileURL.path) {
                    try fileManager.removeItem(at: finalFileURL)
                }
                
                // 3. ย้ายไฟล์จาก Temporary location ไปยัง Application Support
                try fileManager.moveItem(at: tempURL, to: finalFileURL)
                
                print("✅ [File Ready]: ดาวน์โหลดเสร็จและย้ายไปที่ \(finalFileURL.path)")
                
                // 4. บันทึก URL ไฟล์ล่าสุดและเปิด UI แชร์ (บน Main Thread)
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = true
                    self.downloadProgress = 1.0
                    self.currentDownloadFileURL = finalFileURL
                    self.presentShareSheet(for: finalFileURL)
                }
                
            } catch {
                print("❌ [File Operation Error]: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = false
                }
                // คุณอาจจะเพิ่ม showDebugAlert
            }
        }
        
        // เริ่มสังเกต Progress ผ่าน Notification Center
        NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressChanged), name: Notification.Name("URLSessionDownloadProgress"), object: downloadTask)
        
        downloadTask?.resume()
    }
    
    /// สังเกต Progress ของ Task (ต้องมี Extension ของ URLSession เพิ่มเติมเพื่อส่ง Notification)
    @objc private func downloadProgressChanged(notification: Notification) {
        guard let task = notification.object as? URLSessionDownloadTask,
              task == downloadTask else { return }
        
        if task.countOfBytesExpectedToReceive > 0 {
            let progress = Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive)
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }
    }
    
    // MARK: - Present Share Sheet (NEW)
    
    /// เปิด UI แชร์ไฟล์เพื่อให้ User บันทึกไปติดตั้งเอง
    private func presentShareSheet(for fileURL: URL) {
        DispatchQueue.main.async {
            // ป้องกันการแชร์เมื่อปิด View อัปเดตไปแล้ว
            guard self.isUpdatePresented else {
                self.deleteDownloadedFile(at: fileURL) // ลบทิ้งถ้า View ปิดไปแล้ว
                return
            }
            
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            // สำหรับ iPad
            if let popoverController = activityVC.popoverPresentationController {
                if let topVC = self.getTopViewController() {
                    popoverController.sourceView = topVC.view
                    popoverController.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
            }
            
            // MARK: - ลบไฟล์เมื่อ UI แชร์ปิดตัวลง (บันทึก/ยกเลิก)
            activityVC.completionWithItemsHandler = { [weak self] (activityType, completed, returnedItems, error) in
                guard let self = self else { return }
                // ไม่ว่าจะ completed หรือไม่ (คือ User บันทึก หรือ User กดยกเลิก) เราก็จะลบไฟล์ทิ้งเสมอ
                self.deleteDownloadedFile(at: fileURL)
                self.currentDownloadFileURL = nil
            }
            
            if let topVC = self.getTopViewController() {
                topVC.present(activityVC, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Safe Alert & Present Method (Logic เดิม)
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
    
    func presentUpdateUI(downloadUrl: String?, releaseNotes: String?, versionString: String) {
        DispatchQueue.main.async {
            guard !self.isUpdatePresented else { return }
            self.isUpdatePresented = true
            
            let updateView = AppUpdateView(
                downloadUrl: downloadUrl,
                releaseNotes: releaseNotes,
                versionString: versionString
            )
            
            let hostingController = UIHostingController(rootView: updateView)
            
            if #available(iOS 13.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    window.rootViewController = hostingController
                    window.makeKeyAndVisible()
                    return
                }
            }
            
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
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

// MARK: - Helper Extension to post Notification for URLSessionDownloadTask Progress
class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadProgressDelegate()
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        NotificationCenter.default.post(name: Notification.Name("URLSessionDownloadProgress"), object: downloadTask)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled via completion block in dataTask/downloadTask directly
    }
}
