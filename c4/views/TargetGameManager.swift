import Foundation
import UIKit
import SwiftUI
import TrustKit

// MARK: - TargetGameManager
class TargetGameManager: ObservableObject {
    
    static let shared = TargetGameManager()
    
    typealias FetchGamesHandler = (_ games: [TargetGameApp]) -> Void
    
    private var fetchHandler: FetchGamesHandler?
    
    // MARK: - Target Games State
    @Published var targetApps: [TargetGameApp] = []
    @Published var isLoading: Bool = false
    
    // MARK: - Private Configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config, delegate: TargetGameDelegate.shared, delegateQueue: OperationQueue.main)
    }()
    
    private init() {
        // 🟢 ดักรับสัญญาณ Real-time จาก Pusher ( event: game_updated )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGameUpdateNotification),
            name: NSNotification.Name("RefreshTargetGames"),
            object: nil
        )
    }
    
    @objc private func handleGameUpdateNotification() {
        Task { @MainActor in
            self.fetchTargetGames(showHUD: false)
        }
    }
    
    // MARK: - Fetch Dynamic Games from Server
    func fetchTargetGames(showHUD: Bool = false, handler: FetchGamesHandler? = nil) {
        if let customHandler = handler {
            self.fetchHandler = customHandler
        }
        
        // 🟢 พ่วงแอบตรวจเช็คเวอร์ชันระบบไปด้วยทุกครั้ง
        AppUpdateCheckerManager.shared.checkVersion()
        
        guard let url = URL(string: SecretKeys.targetGamesURL) else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
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
            
            var fetchedApps: [TargetGameApp] = []
            
            if let error = error {
                print("⚠️ [Fetch Games Error / SSL Blocked]: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode), let data = data {
                if let decodedGames = try? JSONDecoder().decode([TargetGameApp].self, from: data) {
                    // กรองเอาเฉพาะเกมที่ active != false
                    fetchedApps = decodedGames.filter { $0.active ?? true }
                }
            }
            
            // การันตีการแสดง HUD อย่างน้อย 1 วินาทีเพื่อความสม่ำเสมอของ UI
            let elapsedTime = Date().timeIntervalSince(startTime)
            let minDuration: TimeInterval = showHUD ? 1.0 : 0.0
            let remainingTime = max(0, minDuration - elapsedTime)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                self.targetApps = fetchedApps
                self.isLoading = false
                if showHUD {
                    HUDHelper.hide()
                }
                self.fetchHandler?(fetchedApps)
            }
        }.resume()
    }
}

// MARK: - SSL Pinning Delegate for TargetGameManager
class TargetGameDelegate: NSObject, URLSessionDataDelegate {
    static let shared = TargetGameDelegate()
    
    // 🟢 ส่ง Authentication Challenge ไปให้ TrustKit ตรวจสอบ Certificate สไตล์เดียวกับ AppUpdate
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let validator = TrustKit.sharedInstance().pinningValidator
        let handled = validator.handle(challenge, completionHandler: completionHandler)
        if handled {
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
