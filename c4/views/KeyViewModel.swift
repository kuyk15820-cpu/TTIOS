import Foundation
import Combine

@MainActor
class KeyViewModel: ObservableObject {
    @Published var keys: [LicenseKey] = []
    @Published var selectedTab: KeyTab = .active
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // สำหรับระบบเลือกหลายรายการ (Bulk Actions)
    @Published var selectedIDs: Set<Int> = []

    private let apiService = APIService.shared

    enum KeyTab: String, CaseIterable {
        case active = "active"
        case banned = "banned"
        case expired = "expired"
        case deleted = "deleted"

        var title: String {
            switch self {
            case .active: return "🟢 Active"
            case .banned: return "🚫 Banned"
            case .expired: return "🟡 Expired"
            case .deleted: return "🔴 Deleted"
            }
        }
    }

    // MARK: - Data Fetching
    func fetchKeys() async {
        isLoading = true
        errorMessage = nil
        selectedIDs.removeAll()

        do {
            self.keys = try await apiService.getKeys(tab: selectedTab.rawValue)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Key Creation
    func createKey(
        projectId: Int,
        prefixType: String,
        customPrefix: String?,
        type: KeyType,
        maxDevices: Int,
        staticDate: String?,
        durationNum: Int,
        durationUnit: String
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await apiService.createKey(
                projectId: projectId,
                prefixType: prefixType,
                customPrefix: customPrefix,
                type: type.rawValue,
                maxDevices: maxDevices,
                staticDate: staticDate,
                durationNum: durationNum,
                durationUnit: durationUnit
            )
            if success {
                await fetchKeys()
                return true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        return false
    }

    // MARK: - Key Management Actions
    func renewKey(id: Int, num: Int, unit: String) async {
        do {
            let success = try await apiService.renewKey(id: id, num: num, unit: unit)
            if success { await fetchKeys() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func resetDevice(id: Int) async {
        do {
            let success = try await apiService.resetDevice(id: id)
            if success { await fetchKeys() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func resetAllDevices() async {
        do {
            let success = try meOrApiServiceResetAll()
            if success { await fetchKeys() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func meOrApiServiceResetAll() async throws -> Bool {
        return try await apiService.resetAllDevices()
    }

    func banKey(id: Int, banType: String, hours: Int?, reason: String) async {
        do {
            let success = try await apiService.banKey(id: id, banType: banType, hours: hours, reason: reason)
            if success { await fetchKeys() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func unbanKey(id: Int) async {
        do {
            let success = try await apiService.unbanKey(id: id)
            if success { await fetchKeys() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteKey(id: Int) async {
        do {
            let success = try await apiService.deleteKey(id: id)
            if success { await fetchKeys() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bulk Actions & Clear All
    func executeBulkAction(_ action: String) async {
        guard !selectedIDs.isEmpty else { return }

        do {
            let ids = Array(selectedIDs)
            let success = try await apiService.executeKeyBulkAction(action: action, ids: ids, currentTab: selectedTab.rawValue)
            if success {
                selectedIDs.removeAll()
                await fetchKeys()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func clearAllInCurrentTab() async {
        do {
            let success = try await apiService.clearKeysInTab(tab: selectedTab.rawValue)
            if success { await fetchKeys() }
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
        selectedIDs = Set(keys.map { $0.id })
    }

    func deselectAll() {
        selectedIDs.removeAll()
    }
}
