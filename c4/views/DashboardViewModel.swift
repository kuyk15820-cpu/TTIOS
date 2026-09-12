import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: DashboardStats = DashboardStats()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // อ้างอิง Network Service (เดี๋ยวเราจะสร้าง APIService.swift ในขั้นตอนถัดไป)
    private let apiService = APIService.shared

    func fetchDashboardStats() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedStats = try await apiService.getDashboardStats()
            self.stats = fetchedStats
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
