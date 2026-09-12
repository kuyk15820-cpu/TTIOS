import Foundation

// MARK: - Dashboard Stats Model
struct DashboardStats: Codable, Hashable {
    let totalActiveKeys: Int
    let totalBannedKeys: Int
    let totalExpiredKeys: Int
    let totalDeletedKeys: Int
    
    let totalProjects: Int
    let totalActiveProjects: Int
    let totalMaintProjects: Int
    let totalDeletedProjects: Int
    
    let totalBoundDevices: Int

    enum CodingKeys: String, CodingKey {
        case totalActiveKeys = "total_active_keys"
        case totalBannedKeys = "total_banned_keys"
        case totalExpiredKeys = "total_expired_keys"
        case totalDeletedKeys = "total_deleted_keys"
        
        case totalProjects = "total_projects"
        case totalActiveProjects = "total_active_projects"
        case totalMaintProjects = "total_maint_projects"
        case totalDeletedProjects = "total_deleted_projects"
        
        case totalBoundDevices = "total_bound_devices"
    }

    // Default Initializer / Mock Data สำหรับใช้ใน SwiftUI Preview
    init(
        totalActiveKeys: Int = 0,
        totalBannedKeys: Int = 0,
        totalExpiredKeys: Int = 0,
        totalDeletedKeys: Int = 0,
        totalProjects: Int = 0,
        totalActiveProjects: Int = 0,
        totalMaintProjects: Int = 0,
        totalDeletedProjects: Int = 0,
        totalBoundDevices: Int = 0
    ) {
        self.totalActiveKeys = totalActiveKeys
        self.totalBannedKeys = totalBannedKeys
        self.totalExpiredKeys = totalExpiredKeys
        self.totalDeletedKeys = totalDeletedKeys
        self.totalProjects = totalProjects
        self.totalActiveProjects = totalActiveProjects
        self.totalMaintProjects = totalMaintProjects
        self.totalDeletedProjects = totalDeletedProjects
        self.totalBoundDevices = totalBoundDevices
    }
}
