import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String

    // Initializer สำหรับใส่ทั้ง name และ bundleID
    init(name: String, bundleID: String) {
        self.name = name
        self.bundleID = bundleID
    }

    // Initializer แบบระบุแค่ bundleID
    init(bundleID: String) {
        self.bundleID = bundleID
        self.name = TargetGameApp.fetchAppName(for: bundleID)
    }

    var icon: UIImage? {
        UIImage.applicationIcon(forBundleIdentifier: bundleID)
    }

    // MARK: - Private Helpers

    private static func fetchAppName(for bundleID: String) -> String {
        let presetApps: [String: String] = [
            "com.dts.freefireth": "Free Fire",
            "com.dts.freefiremax": "Free Fire MAX"
        ]
        
        if let presetName = presetApps[bundleID] {
            return presetName
        }

        if let proxyClass = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
           let proxy = proxyClass.perform(Selector(("applicationProxyForIdentifier:")), with: bundleID)?.takeUnretainedValue() as? NSObject {
            
            if let localizedName = proxy.perform(Selector(("localizedName")))?.takeUnretainedValue() as? String, !localizedName.isEmpty {
                return localizedName
            }
        }

        let fallback = bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
        return fallback
    }
    
    static func == (lhs: TargetGameApp, rhs: TargetGameApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}
