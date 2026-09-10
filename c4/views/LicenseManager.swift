import Foundation
import UIKit

// MARK: - Models
struct InitData: Decodable {
    let status: Bool
    let contact: String?
    let maintenance: Bool?
    let forceExit: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status, contact, maintenance, message
        case forceExit = "force_exit"
    }
}

struct KeyValidationData: Decodable {
    let status: Bool
    let message: String?
    let expiry: String?
    let daysLeft: Int?
    let contact: String?
    let forceExit: Bool?

    enum CodingKeys: String, CodingKey {
        case status, message, expiry, contact
        case daysLeft = "days_left"
        case forceExit = "force_exit"
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
        }
    }
    
    var deviceUUID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_UUID"
    }

    // MARK: - API Calls
    
    /// 1. เช็กสถานะ Server และ Maintenance
    func checkInit() async throws -> InitData {
        let urlString = "\(APIConfig.baseURL)?action=init&token=\(APIConfig.packageToken)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(InitData.self, from: data)
        
        self.contactLink = response.contact
        self.isMaintenance = response.maintenance ?? false
        
        return response
    }
    
    /// 2. ตรวจสอบและยืนยัน Key
    func verifyKey(_ key: String) async throws -> KeyValidationData {
        let urlString = "\(APIConfig.baseURL)?action=check&token=\(APIConfig.packageToken)&key=\(key)&uuid=\(deviceUUID)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(KeyValidationData.self, from: data)
        
        if let contact = response.contact {
            self.contactLink = contact
        }
        
        return response
    }
}
