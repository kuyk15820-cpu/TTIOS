import Foundation

// MARK: - License Key Model
struct LicenseKey: Identifiable, Codable, Hashable {
    let id: Int
    let projectId: Int
    let tokenCode: String
    let type: KeyType
    let duration: Int
    var expireDate: String?
    let maxDevices: Int
    var isBanned: Bool
    var banExpire: String?
    var banReason: String?
    var pname: String?            // ชื่อ Package ที่ JOIN มาจากตาราง tbl_projects
    var devices: [BoundDevice]   // รายการ อุปกรณ์ (UDIDs) ที่ผูกอยู่กับ Key นี้
    var reason: String?           // เหตุผลการลบ (สำหรับ History Tab)
    var deletedAt: String?        // วันที่ถูกลบ (สำหรับ History Tab)

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case tokenCode = "token_code"
        case type
        case duration
        case expireDate = "expire_date"
        case maxDevices = "max_devices"
        case isBanned = "is_banned"
        case banExpire = "ban_expire"
        case banReason = "ban_reason"
        case pname
        case devices
        case reason
        case deletedAt = "deleted_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        projectId = try container.decode(Int.self, forKey: .projectId)
        tokenCode = try container.decode(String.self, forKey: .tokenCode)
        
        // Custom Enum decoding
        let typeString = try container.decode(String.self, forKey: .type)
        type = KeyType(rawValue: typeString) ?? .dynamic

        duration = try container.decode(Int.self, forKey: .duration)
        expireDate = try container.decodeIfPresent(String.self, forKey: .expireDate)
        maxDevices = try container.decode(Int.self, forKey: .maxDevices)
        
        // ป้องกัน Crash จากค่า is_banned ที่อาจส่งมาเป็น 1/0 หรือ Bool
        if let bannedInt = try? container.decode(Int.self, forKey: .isBanned) {
            isBanned = (bannedInt == 1)
        } else if let bannedBool = try? container.decode(Bool.self, forKey: .isBanned) {
            isBanned = bannedBool
        } else {
            isBanned = false
        }

        banExpire = try container.decodeIfPresent(String.self, forKey: .banExpire)
        banReason = try container.decodeIfPresent(String.self, forKey: .banReason)
        pname = try container.decodeIfPresent(String.self, forKey: .pname)
        devices = try container.decodeIfPresent([BoundDevice].self, forKey: .devices) ?? []
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
    }

    // Explicit Init สำหรับสร้าง Mock Data / Testing ใน SwiftUI Preview
    init(
        id: Int,
        projectId: Int,
        tokenCode: String,
        type: KeyType,
        duration: Int,
        expireDate: String? = nil,
        maxDevices: Int = 1,
        isBanned: Bool = false,
        banExpire: String? = nil,
        banReason: String? = nil,
        pname: String? = nil,
        devices: [BoundDevice] = [],
        reason: String? = nil,
        deletedAt: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.tokenCode = tokenCode
        self.type = type
        self.duration = duration
        self.expireDate = expireDate
        self.maxDevices = maxDevices
        self.isBanned = isBanned
        self.banExpire = banExpire
        self.banReason = banReason
        self.pname = pname
        self.devices = devices
        self.reason = reason
        self.deletedAt = deletedAt
    }

    // Helper ในการตรวจสอบว่า Key หมดอายุแล้วหรือยัง
    var isExpired: Bool {
        if type == .lifetime || duration == -1 { return false }
        guard let expireDate = expireDate, !expireDate.isEmpty else { return false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Bangkok")
        
        if let date = formatter.date(from: expireDate) {
            return date < Date()
        }
        return false
    }

    // Helper สรุปจำนวน อุปกรณ์ที่ใช้อยู่จริง เช่น "1 / 3"
    var deviceUsageString: String {
        "\(devices.count) / \(maxDevices)"
    }
}

// MARK: - Key Type Enum
enum KeyType: String, Codable, CaseIterable {
    case dynamic = "dynamic"
    case staticKey = "static"
    case lifetime = "lifetime"

    var displayName: String {
        switch self {
        case .dynamic: return "Key Dynamic"
        case .staticKey: return "Key Static"
        case .lifetime: return "Key Lifetime (∞)"
        }
    }
}

// MARK: - Bound Device Sub-model (tbl_device_history)
struct BoundDevice: Identifiable, Codable, Hashable {
    var id: String { deviceUuid } // ใช้ UUID เป็น ID ประจำตัวใน SwiftUI List
    let deviceUuid: String
    let boundAt: String?

    enum CodingKeys: String, CodingKey {
        case deviceUuid = "device_uuid"
        case boundAt = "bound_at"
    }
}
