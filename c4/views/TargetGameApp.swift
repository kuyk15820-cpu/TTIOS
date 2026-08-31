import SwiftUI
import UIKit

struct TargetGameApp: Identifiable, Hashable, Decodable {
    var id: String { bundleID }
    let name: String
    let bundleID: String
    let active: Bool? // 🟢 เพิ่ม Property รับสถานะเปิด/ปิดใช้งานจาก JSON

    enum CodingKeys: String, CodingKey {
        case name
        case bundleID
        case active
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

        // หากฝั่ง Server ไม่ได้ส่งฟิลด์ active มา ให้ Default เป็น true
        self.active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
    }

    // Initializer สำหรับใส่ทั้ง name และ bundleID
    init(name: String, bundleID: String, active: Bool? = true) {
        self.name = name
        self.bundleID = bundleID
        self.active = active
    }

    // Initializer แบบระบุแค่ bundleID
    init(bundleID: String, active: Bool? = true) {
        self.bundleID = bundleID
        self.name = TargetGameApp.fetchAppName(for: bundleID)
        self.active = active
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
