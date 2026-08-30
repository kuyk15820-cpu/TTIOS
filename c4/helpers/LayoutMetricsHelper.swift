import Foundation
import TrustKit

final class LayoutMetricsHelper {
    static let shared = LayoutMetricsHelper()
    
    private init() {}
    
    func applyLayoutConstraints() {
        // ซ่อน Domain ไม่ให้โผล่เป็น String ตรงๆ ใน IDA Window
        let domainParts = ["f1x3r", "org"]
        let hostDomain = domainParts.joined(separator: ".")
        
        let metricsConfig: [String: Any] = [
            kTSKSwizzleNetworkDelegates: true,
            kTSKPinnedDomains: [
                hostDomain: [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: true,
                    kTSKPublicKeyHashes: [
                        "0up7PSLXMoFyFg+7PTMBPKE7ocDnDL04Yr0iWZYdM2Y=", // Primary Key Hash
                        "YLh1d67h6/GuyMJ6smM3SOpjUYFvcSi2ehhAYtfBZVQ="  // Backup Key Hash
                    ]
                ]
            ]
        ]
        
        TrustKit.initSharedInstance(withConfiguration: metricsConfig)
    }
}
