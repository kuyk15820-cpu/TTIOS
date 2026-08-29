import Foundation
import UIKit
import SwiftUI

// MARK: - AppUpdateCheckerManager
class AppUpdateCheckerManager: ObservableObject {
    
    static let shared = AppUpdateCheckerManager()
    
    typealias UpdateCheckHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var updateHandler: UpdateCheckHandler?
    private var isUpdatePresented: Bool = false
    
    // MARK: - Window Management (สำหรับกันหน้า Quick หลุด)
    private var overlayWindow: UIWindow?
    
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
    
    // MARK: - Start Checking Version
    func checkVersion(handler: UpdateCheckHandler? = nil) {
        // สร้าง Overlay Window บดบังหน้า Quick ไว้ทันทีก่อนยิง Network
        self.prepareOverlayWindow()
        
        if let customHandler = handler {
            self.updateHandler = customHandler
        } else {
            self.updateHandler = { [weak self] needsUpdate, downloadUrl, releaseNotes, serverVersion in
                guard let self = self else { return }
                if needsUpdate {
                    self.presentUpdateUI(downloadUrl: downloadUrl, releaseNotes: releaseNotes, versionString: serverVersion)
                } else {
                    // ถ้าไม่มีอัปเดต ให้ลบ Window สีดำทิ้งเพื่อให้เห็นหน้าแอปตามปกติ
                    self.dismissOverlayWindow()
                }
            }
        }
        
        guard let url = URL(string: "https://f1x3r.org/pv/app_version.php") else {
            self.dismissOverlayWindow()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ [HTTP Error]: \(error.localizedDescription)")
                self.dismissOverlayWindow()
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("⚠️ [JSON Error]: ไม่สามารถอ่านข้อมูล JSON จาก PHP Server ได้")
                self.dismissOverlayWindow()
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
            
            if !isBundleValid || !isAppNameValid || !isVersionAllowed {
                self.updateHandler?(true, downloadUrl, releaseNotes, serverVersion)
            } else {
                self.updateHandler?(false, downloadUrl, releaseNotes, serverVersion)
            }
        }.resume()
    }
    
    // MARK: - Window Overlay Management
    
    /// สร้าง Window เปล่าสีดำทับไว้ก่อนทันทีเพื่อบังหน้า Quick
    private func prepareOverlayWindow() {
        DispatchQueue.main.async {
            let rootVC = UIViewController()
            rootVC.view.backgroundColor = .black
            
            if #available(iOS 13.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    let window = UIWindow(windowScene: windowScene)
                    window.rootViewController = rootVC
                    window.windowLevel = .alert + 1
                    window.makeKeyAndVisible()
                    self.overlayWindow = window
                    return
                }
            }
            
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = rootVC
            window.windowLevel = .alert + 1
            window.makeKeyAndVisible()
            self.overlayWindow = window
        }
    }
    
    /// ลบ Window สีดำทิ้งกรณีไม่มีอัปเดต
    private func dismissOverlayWindow() {
        DispatchQueue.main.async {
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
        }
    }
    
    // MARK: - Present Update UI (สไลด์ขึ้นมาเหมือนเดิม)
    
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
            
            // ตั้งค่า Animation สไลด์แบบเดิม (.fullScreen หรือ .pageSheet)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.isModalInPresentation = true
            
            // สั่งให้สไลด์ขึ้นมาจาก Overlay Window ที่เราเตรียมไว้
            if let rootVC = self.overlayWindow?.rootViewController {
                rootVC.present(hostingController, animated: true, completion: nil)
            } else if let topVC = self.getTopViewController() {
                topVC.present(hostingController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - File & Download Logic
    private func getDownloadDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        
        let downloadURL = appSupportURL.appendingPathComponent(".download", isDirectory: true)
        if !fileManager.fileExists(atPath: downloadURL.path) {
            try fileManager.createDirectory(at: downloadURL, withIntermediateDirectories: true, attributes: nil)
        }
        return downloadURL
    }
    
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
    func startDownload(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.isDownloaded = false
            self.downloadProgress = 0.0
            self.currentDownloadFileURL = nil
        }
        
        downloadTask?.cancel()
        
        downloadTask = urlSession.downloadTask(with: url) { [weak self] (tempURL, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [Download Error]: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isDownloaded = false
                }
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
                let downloadDir = try self.getDownloadDirectoryURL()
                let suggestedFilename = response?.suggestedFilename ?? url.lastPathComponent
                let finalFileURL = downloadDir.appendingPathComponent(suggestedFilename)
                
                if fileManager.fileExists(atPath: finalFileURL.path) {
                    try fileManager.removeItem(at: finalFileURL)
                }
                
                try fileManager.moveItem(at: tempURL, to: finalFileURL)
                print("✅ [File Ready]: ดาวน์โหลดเสร็จและย้ายไปที่ \(finalFileURL.path)")
                
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
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressChanged), name: Notification.Name("URLSessionDownloadProgress"), object: downloadTask)
        downloadTask?.resume()
    }
    
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
    
    // MARK: - Present Share Sheet
    private func presentShareSheet(for fileURL: URL) {
        DispatchQueue.main.async {
            guard self.isUpdatePresented else {
                self.deleteDownloadedFile(at: fileURL)
                return
            }
            
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let popoverController = activityVC.popoverPresentationController {
                if let topVC = self.getTopViewController() {
                    popoverController.sourceView = topVC.view
                    popoverController.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
            }
            
            activityVC.completionWithItemsHandler = { [weak self] (activityType, completed, returnedItems, error) in
                guard let self = self else { return }
                self.deleteDownloadedFile(at: fileURL)
                self.currentDownloadFileURL = nil
            }
            
            if let topVC = self.getTopViewController() {
                topVC.present(activityVC, animated: true, completion: nil)
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

// MARK: - Helper Extension
class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadProgressDelegate()
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        NotificationCenter.default.post(name: Notification.Name("URLSessionDownloadProgress"), object: downloadTask)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { }
}
