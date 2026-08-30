import Foundation
import UIKit
import SwiftUI
import TrustKit

// MARK: - AppUpdateCheckerManager
class AppUpdateCheckerManager: ObservableObject {
    
    static let shared = AppUpdateCheckerManager()
    
    typealias UpdateCheckHandler = (_ needsUpdate: Bool, _ downloadUrl: String?, _ releaseNotes: String?, _ serverVersion: String) -> Void
    
    private var updateHandler: UpdateCheckHandler?
    
    // MARK: - App Update State
    @Published var isUpdateNeeded: Bool = false
    @Published var downloadUrl: String?
    @Published var releaseNotes: String?
    @Published var serverVersion: String = SecretKeys.fallbackVersion
    
    // MARK: - Download States
    @Published var isDownloading = false
    @Published var isDownloaded = false
    @Published var isDone = false // 💡 State สำหรับควบคุมปุ่ม Done
    @Published var downloadProgress: Double = 0.0
    @Published var currentDownloadFileURL: URL?
    
    // MARK: - Download Size States
    @Published var totalBytesWritten: Int64 = 0
    @Published var totalBytesExpected: Int64 = 0
    @Published var downloadSizeText: String = ""
    
    // MARK: - Private Configuration
    private var downloadTask: URLSessionDownloadTask?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config, delegate: DownloadProgressDelegate.shared, delegateQueue: OperationQueue.main)
    }()
    
    private init() {}
    
    // MARK: - Start Checking Version
    func checkVersion(handler: UpdateCheckHandler? = nil) {
        if let customHandler = handler {
            self.updateHandler = customHandler
        }
        
        guard let url = URL(string: SecretKeys.appUpdateURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10.0
        request.setValue(SecretKeys.userAgentValue, forHTTPHeaderField: SecretKeys.userAgentHeader)
        
        // 🟢 ใช้ urlSession ที่ผูก Delegate สำหรับ SSL Pinning
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ [HTTP Error / SSL Blocked]: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return }
            
            let currentBundleID = Bundle.main.bundleIdentifier ?? SecretKeys.fallbackNA
            let currentAppName = (Bundle.main.infoDictionary?[SecretKeys.infoCFBundleDisplayName] as? String)
                                ?? (Bundle.main.infoDictionary?[SecretKeys.infoCFBundleName] as? String) ?? SecretKeys.fallbackNA
            let currentVersion = (Bundle.main.infoDictionary?[SecretKeys.infoCFBundleShortVersionString] as? String) ?? SecretKeys.fallbackNA
            
            let serverBundleID = json[SecretKeys.jsonKeyBundleID] as? String ?? SecretKeys.fallbackNA
            let serverAppName = json[SecretKeys.jsonKeyAppName] as? String ?? SecretKeys.fallbackNA
            let serverVersion = json[SecretKeys.jsonKeyLatestVersion] as? String ?? SecretKeys.fallbackVersion
            let allowedVersions = json[SecretKeys.jsonKeyAllowedVersions] as? [String] ?? []
            let downloadUrl = json[SecretKeys.jsonKeyDownloadUrl] as? String
            let releaseNotes = json[SecretKeys.jsonKeyReleaseNotes] as? String
            
            let isBundleValid = (currentBundleID == serverBundleID)
            let isAppNameValid = (currentAppName == SecretKeys.fallbackNA) ? true : (currentAppName == serverAppName)
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
        
        let downloadURL = appSupportURL.appendingPathComponent(SecretKeys.downloadDirectory, isDirectory: true)
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
            self.isDone = false
            self.downloadProgress = 0.0
            self.totalBytesWritten = 0
            self.totalBytesExpected = 0
            self.downloadSizeText = SecretKeys.downloadProgressFormatZero
            self.currentDownloadFileURL = nil
        }
        
        downloadTask?.cancel()
        
        downloadTask = urlSession.downloadTask(with: url)
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name(SecretKeys.downloadProgressNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressChanged), name: Notification.Name(SecretKeys.downloadProgressNotification), object: nil)
        
        downloadTask?.resume()
    }
    
    @objc private func downloadProgressChanged(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let written = userInfo[SecretKeys.dictKeyWritten] as? Int64,
              let expected = userInfo[SecretKeys.dictKeyExpected] as? Int64 else { return }
        
        let sizeText: String
        let progress: Double
        
        if expected > 0 {
            progress = Double(written) / Double(expected)
            let percentage = Int(progress * 100)
            sizeText = "Downloading... (\(percentage)%)"
        } else {
            progress = 0.0
            sizeText = SecretKeys.updateBtnDownloadingDefault
        }
        
        DispatchQueue.main.async {
            self.totalBytesWritten = written
            self.totalBytesExpected = expected
            self.downloadProgress = progress
            self.downloadSizeText = sizeText
        }
    }
    
    func handleDownloadCompletion(tempURL: URL, response: URLResponse?, error: Error?) {
        if error != nil {
            DispatchQueue.main.async {
                self.resetStates()
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            DispatchQueue.main.async {
                self.resetStates()
            }
            return
        }
        
        do {
            let fileManager = FileManager.default
            let downloadDir = try getDownloadDirectoryURL()
            let suggestedFilename = response?.suggestedFilename ?? SecretKeys.defaultIPAFilename
            let finalFileURL = downloadDir.appendingPathComponent(suggestedFilename)
            
            if fileManager.fileExists(atPath: finalFileURL.path) {
                try fileManager.removeItem(at: finalFileURL)
            }
            
            try fileManager.moveItem(at: tempURL, to: finalFileURL)
            
            // 💡 1. ค้าง 100% ให้ผู้ใช้เห็นก่อน 0.5 วินาที
            DispatchQueue.main.async {
                self.downloadProgress = 1.0
                self.downloadSizeText = SecretKeys.downloadProgressFormatHundred
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 💡 2. สลับเป็น Done และเปิด Share Sheet
                self.isDownloading = false
                self.isDone = true
                self.currentDownloadFileURL = finalFileURL
                self.presentShareSheet(for: finalFileURL)
            }
        } catch {
            DispatchQueue.main.async {
                self.resetStates()
            }
        }
    }
    
    private func resetStates() {
        self.isDownloading = false
        self.isDownloaded = false
        self.isDone = false
        self.downloadProgress = 0.0
        self.downloadSizeText = ""
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
                
                // 💡 เมื่อแชร์เสร็จ หรือปิดหน้า Share Sheet ให้รีเซ็ตสถานะกลับเป็น Update now
                DispatchQueue.main.async {
                    self.resetStates()
                }
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

// MARK: - Helper Extension (URLSessionDownloadDelegate & SSL Pinning)
class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadProgressDelegate()
    
    // 🟢 ส่ง Authentication Challenge ไปให้ TrustKit ตรวจสอบ Certificate
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let validator = TrustKit.sharedInstance().pinningValidator
        let handled = validator.handle(challenge, completionHandler: completionHandler)
        if handled {
            return
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let userInfo: [String: Any] = [
            SecretKeys.dictKeyWritten: totalBytesWritten,
            SecretKeys.dictKeyExpected: totalBytesExpectedToWrite
        ]
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name(SecretKeys.downloadProgressNotification),
                object: downloadTask,
                userInfo: userInfo
            )
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        AppUpdateCheckerManager.shared.handleDownloadCompletion(tempURL: location, response: downloadTask.response, error: downloadTask.error)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            AppUpdateCheckerManager.shared.handleDownloadCompletion(tempURL: URL(fileURLWithPath: ""), response: task.response, error: error)
        }
    }
}