import Foundation
import TrustKit

// MARK: - Generic SSL Pinning Delegate
class SSLPinningDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let shared = SSLPinningDelegate()
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let handled = TrustKit.sharedInstance().pinningValidator.handle(challenge, completionHandler: completionHandler)
        if !handled {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Shared SSL Pinned URLSession
extension URLSession {
    static var pinned: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15.0 // 🟢 แก้ไขเป็น timeoutIntervalForRequest
        config.timeoutIntervalForResource = 30.0 // (Optional) ใส่เพิ่มได้ถ้าต้องการคุมเวลาดาวน์โหลดไฟล์จนจบ
        return URLSession(configuration: config, delegate: SSLPinningDelegate.shared, delegateQueue: nil)
    }()
}
