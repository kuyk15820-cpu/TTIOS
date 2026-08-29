import Foundation
import UIKit
import SwiftUI

// MARK: - AppUpdateCheckerManager
class AppUpdateCheckerManager: ObservableObject {
    
    static let shared = AppUpdateCheckerManager()
    
    typealias UpdateCheckHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var updateHandler: UpdateCheckHandler?
    
    // MARK: - App Update State (สำหรับให้ SwiftUI View เอาไปเช็ค)
    @Published var isUpdateNeeded: Bool = false
    @Published var downloadUrl: String?
    @Published var releaseNotes: String?
    @Published var serverVersion: String = "1.0.0"
    
    // MARK: - Download States (สำหรับ UI ดาวน์โหลด)
    @Published var isDownloading = false
    @Published var isDownloaded = false
    @Published var downloadProgress: Double = 0.0
    @Published var currentDownloadFileURL: URL?
    
    // MARK: - Download Size States (เพิ่มส่วนคำนวณขนาดไฟล์)
    @Published var totalBytesWritten: Int64 = 0
    @Published var totalBytesExpected: Int64 = 0
    @Published var downloadSizeText: String = ""
    
    // MARK: - Private Configuration
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: DownloadProgressDelegate.shared, delegateQueue: nil)
    }()
    
    private init() {}
    
    // MARK: - Start Checking Version
    func checkVersion(handler: UpdateCheckHandler? = nil) {
        if let customHandler = handler {
            self.updateHandler = customHandler
        }
        
        guard let url = URL(string: "https://f1x3r.org/pv/app_version.php") else {
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
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("⚠️ [JSON Error]: ไม่สามารถอ่านข้อมูล JSON จาก PHP Server ได้")
                return
            }
            
            let currentBundleID = Bundle.main.bundleIdentifier ?? "N/A"
            let currentAppName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
                                ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "N/A"
            let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "N/A"
            
            let serverBundleID = json["bundleID"] as? String ?? "N/A"
            let serverAppName = json["appName"] as? String ?? "N/A"
            let serverVersion = json["latestVersion"] as? String ?? "1.0.0"
            let allowedVersions = json["allowedVersions"] as? [String] ?? []
            let downloadUrl = json["downloadUrl"] as? String
            let releaseNotes = json["releaseNotes"] as? String
            
            let isBundleValid = (currentBundleID == serverBundleID)
            let isAppNameValid = (currentAppName == "N/A") ? true : (currentAppName == serverAppName)
            let isVersionAllowed = allowedVersions.contains(currentVersion)
            
            let needsUpdate = !isBundleValid || !isAppNameValid || !isVersionAllowed
            
            DispatchQueue.main.async {
                self.isUpdateNeeded = needsUpdate
                self.downloadUrl = downloadUrl
                self.releaseNotes = releaseNotes
                self.serverVersion = serverVersion
                
                self.updateHandler?(needsUpdate, downloadUrl, releaseNotes, serverVersion)
            }
        }.resume()
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
            self.totalBytesWritten = 0
            self.totalBytesExpected = 0
            self.downloadSizeText = "0 MB / 0 MB"
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
              task == downloadTask,
              let userInfo = notification.userInfo,
              let written = userInfo["written"] as? Int64,
              let expected = userInfo["expected"] as? Int64 else { return }
        
        // ฟอร์แมตขนาดไฟล์ด้วย ByteCountFormatter
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        
        let writtenString = formatter.string(fromByteCount: written)
        let expectedString = expected > 0 ? formatter.string(fromByteCount: expected) : "ไม่ทราบขนาด"
        
        let progress = expected > 0 ? Double(written) / Double(expected) : 0.0
        
        DispatchQueue.main.async {
            self.totalBytesWritten = written
            self.totalBytesExpected = expected
            self.downloadProgress = progress
            self.downloadSizeText = "\(writtenString) / \(expectedString)"
        }
    }
    
    // MARK: - Present Share Sheet
    private func presentShareSheet(for fileURL: URL) {
        DispatchQueue.main.async {
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
        let userInfo: [String: Any] = [
            "written": totalBytesWritten,
            "expected": totalBytesExpectedToWrite
        ]
        NotificationCenter.default.post(
            name: Notification.Name("URLSessionDownloadProgress"),
            object: downloadTask,
            userInfo: userInfo
        )
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { }
}
