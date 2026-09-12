import SwiftUI

struct DashboardViews: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    // ตั้งค่า Columns สำหรับ Grid Card Layout
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - License Keys Section
                    Text("หมวดหมู่ Key")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        StatCard(
                            title: "Key ใช้งานได้",
                            value: "\(viewModel.stats.totalActiveKeys)",
                            icon: "key.fill",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Key ที่ถูกแบน",
                            value: "\(viewModel.stats.totalBannedKeys)",
                            icon: "lock.slash.fill",
                            color: .red
                        )
                        
                        StatCard(
                            title: "Key หมดอายุ",
                            value: "\(viewModel.stats.totalExpiredKeys)",
                            icon: "clock.badge.exclamationmark.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "ประวัติ Key ที่ลบ",
                            value: "\(viewModel.stats.totalDeletedKeys)",
                            icon: "trash.fill",
                            color: .gray
                        )
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Devices Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("อุปกรณ์ที่ผูกอยู่ทั้งหมด")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("\(viewModel.stats.totalBoundDevices)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)

                    // MARK: - Projects Section
                    Text("หมวดหมู่ Package")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        StatCard(
                            title: "Package ปกติ",
                            value: "\(viewModel.stats.totalActiveProjects)",
                            icon: "shippingbox.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "ปิดปรับปรุง (Maint)",
                            value: "\(viewModel.stats.totalMaintProjects)",
                            icon: "wrench.and.screwdriver.fill",
                            color: .yellow
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .refreshable {
                await viewModel.fetchDashboardStats()
            }
            .task {
                await viewModel.fetchDashboardStats()
            }
            .overlay {
                if viewModel.isLoading && viewModel.stats.totalProjects == 0 {
                    ProgressView("กำลังโหลดข้อมูล...")
                }
            }
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    DashboardViews()
}
