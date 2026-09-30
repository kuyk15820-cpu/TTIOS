import Foundation
import UIKit
import SwiftUI
import TrustKit

// MARK: - QuickApplyManager
class QuickApplyManager: ObservableObject {
    
    static let shared = QuickApplyManager()
    
    typealias FetchCatalogHandler = (_ items: [QuickPatchItem]) -> Void
    
    private var fetchHandler: FetchCatalogHandler?
    
    // MARK: - Patch Catalog State
    @Published var patchItems: [QuickPatchItem] = []
    @Published var isLoadingCatalog: Bool = false
    
    // MARK: - Private Configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config, delegate: QuickApplyDelegate.shared, delegateQueue: OperationQueue.main)
    }()
    
    private init() {
        // 🟢 ดักรับสัญญาณ Real-time จาก Pusher ( event: patch_updated -> RefreshCatalogPatches )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCatalogUpdateNotification),
            name: NSNotification.Name("RefreshCatalogPatches"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleCatalogUpdateNotification() {
        Task { @MainActor in
            self.fetchCatalog(force: true, showHUD: false)
        }
    }
    
    // MARK: - Fetch Catalog Logic
    func fetchCatalog(force: Bool = false, showHUD: Bool = false, handler: FetchCatalogHandler? = nil) {
        if let customHandler = handler {
            self.fetchHandler = customHandler
        }
        
        // 🟢 การันตีการเรียก Handler เสมอเมื่อ Early Return ป้องกัน Continuation ค้าง (Never Resumed)
        if !patchItems.isEmpty && !force {
            self.fetchHandler?(self.patchItems)
            return
        }
        
        guard let url = URL(string: SecretKeys.catalogURL) else {
            self.fetchHandler?(self.patchItems)
            return
        }
        
        DispatchQueue.main.async {
            self.isLoadingCatalog = true
            if showHUD {
                HUDHelper.show(message: "")
            }
        }
        
        let startTime = Date()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15.0
        request.setValue(SecretKeys.userAgentValue, forHTTPHeaderField: SecretKeys.userAgentHeader)
        
        // 🟢 ใช้ urlSession ที่ผูก Delegate SSL Pinning ผ่าน TrustKit
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            var fetchedItems: [QuickPatchItem] = []
            
            if let error = error {
                print("⚠️ [Fetch Catalog Error / SSL Blocked]: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode), let data = data {
                if let decodedItems = try? JSONDecoder().decode([QuickPatchItem].self, from: data) {
                    fetchedItems = decodedItems
                }
            }
            
            // การันตีการแสดง HUD อย่างน้อย 1 วินาทีเพื่อความสม่ำเสมอของ UI
            let elapsedTime = Date().timeIntervalSince(startTime)
            let minDuration: TimeInterval = showHUD ? 1.0 : 0.0
            let remainingTime = max(0, minDuration - elapsedTime)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                // 🟢 ใส่ Animation ลื่นๆ เมื่อรายการ Catalog มีการอัปเดต/เปลี่ยนแปลง
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.patchItems = fetchedItems
                }
                self.isLoadingCatalog = false
                if showHUD {
                    HUDHelper.hide()
                }
                self.fetchHandler?(fetchedItems)
            }
        }.resume()
    }
    
    // MARK: - Safe Async Wrapper (ป้องกัน Double Resume Crash)
    func fetchCatalog(force: Bool = false, showHUD: Bool = false) async {
        await withCheckedContinuation { continuation in
            var isResumed = false
            let lock = NSLock()
            
            fetchCatalog(force: force, showHUD: showHUD) { _ in
                lock.lock()
                defer { lock.unlock() }
                
                if !isResumed {
                    isResumed = true
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - SSL Pinning Delegate for QuickApplyManager
class QuickApplyDelegate: NSObject, URLSessionDataDelegate {
    static let shared = QuickApplyDelegate()
    
    // 🟢 ส่ง Authentication Challenge ไปให้ TrustKit ตรวจสอบ Certificate สไตล์เดียวกับ TargetGameManager
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let validator = TrustKit.sharedInstance().pinningValidator
        let handled = validator.handle(challenge, completionHandler: completionHandler)
        if handled {
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
