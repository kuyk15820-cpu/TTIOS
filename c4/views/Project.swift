import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: Int
    var name: String
    let projectToken: String
    var contactLink: String?
    var isMaintenance: Bool
    var deletedAt: String?

    // Mapping Key จาก JSON (snake_case) ให้เป็น Swift Standard (camelCase)
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case projectToken = "project_token"
        case contactLink = "contact_link"
        case isMaintenance = "is_maintenance"
        case deletedAt = "deleted_at"
    }

    // Custom Decoder เพื่อรองรับทั้ง Int (0/1) และ Bool ที่ส่งมาจาก PHP API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        projectToken = try container.decode(String.self, forKey: .projectToken)
        contactLink = try container.decodeIfPresent(String.self, forKey: .contactLink)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)

        // แปลงค่า is_maintenance จาก Int (1/0) หรือ Bool ใน JSON ให้เป็น Bool ของ Swift
        if let maintInt = try? container.decode(Int.self, forKey: .isMaintenance) {
            isMaintenance = (maintInt == 1)
        } else if let maintBool = try? container.decode(Bool.self, forKey: .isMaintenance) {
            isMaintenance = maintBool
        } else {
            isMaintenance = false
        }
    }

    // Explicit Initializer สำหรับใช้สร้าง Dummy Data หรือ Testing ใน Preview
    init(id: Int, name: String, projectToken: String, contactLink: String? = nil, isMaintenance: Bool = false, deletedAt: String? = nil) {
        self.id = id
        self.name = name
        self.projectToken = projectToken
        self.contactLink = contactLink
        self.isMaintenance = isMaintenance
        self.deletedAt = deletedAt
    }
}
