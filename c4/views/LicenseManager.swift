import Foundation
import UIKit

// MARK: - Models
struct InitData: Decodable {
    let status: Bool
    let contact: String?
    let maintenance: Int? // รองรับ Int (0 หรือ 1) จาก PHP
    let forceExit: Bool?
    let message: String?
    let errCode: String?

    enum CodingKeys: String, CodingKey {
        case status, contact, maintenance, message
        case forceExit = "force_exit"
        case errCode = "err_code"
    }
}

struct KeyValidationData: Decodable {
    let status: Bool
    let message: String?
    let expiry: String?
    let daysLeft: Int?
    let contact: String?
    let forceExit: Bool?
    
    // 🟢 เพิ่มข้อมูลที่รองรับ PHP API ล่าสุด
    let errCode: String?
    let reason: String?
    let banUntil: String?

    enum CodingKeys: String, CodingKey {
        case status, message, expiry, contact, reason
        case daysLeft = "days_left"
        case forceExit = "force_exit"
        case errCode = "err_code"
        case banUntil = "ban_until"
    }
}

// MARK: - License Manager
final class LicenseManager {
    static let shared = LicenseManager()
    
    private let keyStorage = "saved_license_key"
    
    var contactLink: String?
    var isMaintenance: Bool = false
    
    var savedKey: String? {
        get { UserDefaults.standard.string(forKey: keyStorage) }
        set { 
            if let key = newValue {
                UserDefaults.standard.set(key, forKey: keyStorage)
            } else {
                UserDefaults.standard.removeObject(forKey: keyStorage)
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    var deviceUUID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_UUID"
    }

    // MARK: - API Calls
    
    /// 1. เช็กสถานะ Server และ Maintenance
    func checkInit() async throws -> InitData {
        let urlString = "\(APIConfig.baseURL)?action=init&token=\(APIConfig.packageToken)"
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else { 
            throw URLError(.badURL) 
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(InitData.self, from: data)
        
        self.contactLink = response.contact
        self.isMaintenance = (response.maintenance == 1)
        
        return response
    }
    
    /// 2. ตรวจสอบและยืนยัน Key
    func verifyKey(_ key: String) async throws -> KeyValidationData {
        // 🟢 เพิ่ม Percent Encoding รองรับสัญลักษณ์พิเศษ เช่น '∞' ใน Lifetime Key
        let urlString = "\(APIConfig.baseURL)?action=check&token=\(APIConfig.packageToken)&key=\(key)&uuid=\(deviceUUID)"
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else { 
            self.savedKey = nil
            throw URLError(.badURL) 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(KeyValidationData.self, from: data)
            
            if let contact = response.contact {
                self.contactLink = contact
            }
            
            // 🟢 ปรับการล้างคีย์: ยอมรับกรณี Lifetime Key (daysLeft = 99999)
            // จะล้างค่าในเครื่องเฉพาะเมื่อ status เป็น false หรือถูกสั่ง force_exit เท่านั้น
            if !response.status || response.forceExit == true {
                self.savedKey = nil
            }
            
            return response
        } catch {
            // หากเกิด Network Error หรือ JSON Response ผิดปกติ ให้ล้าง Key ป้องกันการค้างใน Memory
            self.savedKey = nil
            throw error
        }
    }
}
