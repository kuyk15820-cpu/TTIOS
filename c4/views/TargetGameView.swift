import SwiftUI

struct TargetGameView: View {
    // 1. ดึง Manager เข้ามาสังเกต State
    @StateObject private var updateManager = AppUpdateCheckerManager.shared

    private let defaultApps: [TargetGameApp] = [
        TargetGameApp(bundleID: "com.dts.freefireth"),
        TargetGameApp(bundleID: "com.dts.freefiremax")        
    ]

    // แอปของคุณที่จะแสดงเมื่อมีอัปเดตใหม่
    private let myOwnApps: [TargetGameApp] = [
        TargetGameApp(bundleID: "com.apple.mobile.MobileHouseArrest") 
    ]

    // 2. คำนวณรายการแอปที่จะแสดงตามสถานะอัปเดต (ใช้ isUpdateNeeded)
    private var displayedApps: [TargetGameApp] {
        if updateManager.isUpdateNeeded {
            return myOwnApps
        } else {
            return defaultApps
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(displayedApps) { app in
                        NavigationLink(value: app) {
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(uiImage: icon)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "app.window.checkmark")
                                        .font(.title2)
                                        .foregroundStyle(Color.primary)
                                }

                                Text(app.name)
                                    .font(.headline)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    // 3. ปรับ Header Text ตามสถานะอัปเดต (ใช้ isUpdateNeeded)
                    Text(updateManager.isUpdateNeeded ? "มีอัปเดตใหม่" : "เลือกเกม")
                }
            }
            .listStyle(.plain)
            .navigationTitle(updateManager.isUpdateNeeded ? "อัปเดตซอฟต์แวร์" : "หน้าแรก")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TargetGameApp.self) { app in
                QuickApplyView(selectedApp: app)
            }
            .onAppear {
                updateManager.checkVersion()
            }
            // 💡 บังคับให้ SwiftUI วาด UI ใหม่ทันทีเมื่อค่า isUpdateNeeded เปลี่ยนแปลง
            .id(updateManager.isUpdateNeeded)
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
