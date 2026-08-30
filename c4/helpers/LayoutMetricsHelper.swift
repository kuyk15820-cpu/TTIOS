import Foundation
import TrustKit

final class LayoutMetricsHelper {
    static let shared = LayoutMetricsHelper()
    
    private init() {}
    
    func applyLayoutConstraints() {
        let metricsConfig: [String: Any] = [
            kTSKSwizzleNetworkDelegates: true,
            kTSKPinnedDomains: [
                SecretKeys.hostDomain: [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: true,
                    kTSKPublicKeyHashes: [
                        SecretKeys.primaryPublicKeyHash,
                        SecretKeys.backupPublicKeyHash
                    ]
                ]
            ]
        ]
        
        TrustKit.initSharedInstance(withConfiguration: metricsConfig)
    }
}
