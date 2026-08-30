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
        config.timeoutInterval = 15.0
        return URLSession(configuration: config, delegate: SSLPinningDelegate.shared, delegateQueue: nil)
    }()
}
