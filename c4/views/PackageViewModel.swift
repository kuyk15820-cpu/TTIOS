import Foundation
import Combine

@MainActor
class PackageViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedTab: PackageTab = .active
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // สำหรับจัดการการเลือกหลายรายการ (Bulk Actions)
    @Published var selectedIDs: Set<Int> = []
    
    private let apiService = APIService.shared

    enum PackageTab: String, CaseIterable {
        case active = "active"
        case maintenance = "maint"
        case deleted = "deleted"
        
        var title: String {
            switch self {
            case .active: return "🟢 Active"
            case .maintenance: return "🛠️ Maintenance"
            case .deleted: return "🔴 Deleted"
            }
        }
    }

    // MARK: - Data Fetching
    func fetchProjects() async {
        isLoading = true
        errorMessage = nil
        selectedIDs.removeAll()

        do {
            self.projects = try await apiService.getProjects(tab: selectedTab.rawValue)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Single Actions
    func createProject(name: String, contact: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await apiService.createProject(name: name, contact: contact)
            if success {
                await fetchProjects()
                return true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        return false
    }

    func updateProject(id: Int, name: String, contact: String) async {
        do {
            let success = try await apiService.updateProject(id: id, name: name, contact: contact)
            if success { await fetchProjects() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func toggleMaintenance(id: Int, currentStatus: Bool) async {
        do {
            let success = try await apiService.toggleProjectMaintenance(id: id, isMaintenance: !currentStatus)
            if success { await fetchProjects() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteProject(id: Int) async {
        do {
            let success = try await apiService.deleteProject(id: id)
            if success { await fetchProjects() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func restoreProject(id: Int) async {
        do {
            let success = try await apiService.restoreProject(id: id)
            if success { await fetchProjects() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bulk Actions & Clear All
    func executeBulkAction(_ action: String) async {
        guard !selectedIDs.isEmpty else { return }
        
        do {
            let ids = Array(selectedIDs)
            let success = try await apiService.executeProjectBulkAction(action: action, ids: ids, currentTab: selectedTab.rawValue)
            if success {
                selectedIDs.removeAll()
                await fetchProjects()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func clearAllInCurrentTab() async {
        do {
            let success = try await apiService.clearProjectsInTab(tab: selectedTab.rawValue)
            if success { await fetchProjects() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Selection Helpers
    func toggleSelection(for id: Int) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(projects.map { $0.id })
    }

    func deselectAll() {
        selectedIDs.removeAll()
    }
}
