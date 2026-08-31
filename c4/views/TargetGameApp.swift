import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable, Decodable {
    var id: String { bundleID }
    let name: String
    let bundleID: String

    enum CodingKeys: String, CodingKey {
        case name
        case bundleID
    }

    // MARK: - Decodable Initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleID = try container.decode(String.self, forKey: .bundleID)
        
        if let decodedName = try container.decodeIfPresent(String.self, forKey: .name), !decodedName.isEmpty {
            self.name = decodedName
        } else {
            self.name = TargetGameApp.fetchAppName(for: self.bundleID)
        }
    }

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
        if let proxyClass = NSClassFromString(SecretKeys.classNameLSApplicationProxy) as? NSObject.Type,
           let proxy = proxyClass.perform(Selector((SecretKeys.selectorAppProxyForIdentifier)), with: bundleID)?.takeUnretainedValue() as? NSObject {
            
            if let localizedName = proxy.perform(Selector((SecretKeys.selectorLocalizedName)))?.takeUnretainedValue() as? String, !localizedName.isEmpty {
                return localizedName
            }
        }

        return bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
    }
    
    static func == (lhs: TargetGameApp, rhs: TargetGameApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}
