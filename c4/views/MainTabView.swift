import SwiftUI

// MARK: - Main Tab Bar View
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            PackageListView()
                .tabItem {
                    Label("Packages", systemImage: "shippingbox.fill")
                }
                .tag(1)

            KeyListView()
                .tabItem {
                    Label("License Keys", systemImage: "key.fill")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}

// MARK: - App Entry Point
@main
struct AdminDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
