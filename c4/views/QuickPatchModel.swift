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

// MARK: - Models
struct QuickPatchItem: Identifiable, Codable {
    let id: String
    let title: String
    let updatedAt: String?
    let downloadUrl: String
    let active: Bool?
    let category: String?
    let bundleID: String?
    
    var isAimCategory: Bool {
        if let cat = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !cat.isEmpty {
            return cat == SecretKeys.categoryAim
        }
        let text = "\(id) \(title)".lowercased()
        return text.contains(SecretKeys.searchKeyAim) || text.contains(SecretKeys.searchKeyDrag) || text.contains(SecretKeys.searchKeyHead)
    }
}
