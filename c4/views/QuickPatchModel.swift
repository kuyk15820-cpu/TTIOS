import Foundation
import SwiftUI
import SwiftDate

// MARK: - Native List Row Button Style ( Highlighting Effect )
struct NativeListRowButtonStyle: ButtonStyle {
    let isDisabled: Bool
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1.0)
    }
}

// MARK: - Relative Date Helpers
extension String {
    var toRelativeTimeText: String {
        let gregorianRegion = Region(calendar: Calendars.gregorian, zone: Zones.current, locale: Locales.thai)
        
        guard let date = self.toDate(region: gregorianRegion)?.date else {
            return self
        }
        
        let now = Date()
        let safeDate = min(date, now)
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: SecretKeys.localeThaiGregorian)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        
        return formatter.localizedString(for: safeDate, relativeTo: now)
    }
}

// MARK: - Models// MARK: - Models
struct QuickPatchItem: Identifiable, Codable {
    let id: String
    let title: String
    let updatedAt: String?
    let downloadUrl: String
    let active: Bool?
    let category: String?
    let bundleID: String?
    
    // 🟢 เพิ่ม property นี้เข้าไปครับ
    let previewImages: [String]?
    
    // 🟢 (ตัวเลือกเพิ่มเติม) หาก Key จาก API ใน JSON ไม่ได้ชื่อ previewImages ตรงๆ 
    // ให้ใช้ CodingKeys แมปชื่อให้ตรงกับ Server (เช่น preview_images)
    enum CodingKeys: String, CodingKey {
        case id, title, updatedAt, downloadUrl, active, category, bundleID
        case previewImages = "preview_images" // 💡 ปรับชื่อฝั่งขวาตาม JSON จาก API ของคุณ
    }
    
    var isAimCategory: Bool {
        if let cat = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !cat.isEmpty {
            return cat == SecretKeys.categoryAim
        }
        let text = "\(id) \(title)".lowercased()
        return text.contains(SecretKeys.searchKeyAim) || text.contains(SecretKeys.searchKeyDrag) || text.contains(SecretKeys.searchKeyHead)
    }
}
