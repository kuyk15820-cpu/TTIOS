import SwiftUI

struct TargetGameView: View {
    @StateObject private var updateManager = AppUpdateCheckerManager.shared

    private let defaultApps: [TargetGameApp] = [
        TargetGameApp(bundleID: "com.dts.freefireth"),
        TargetGameApp(bundleID: "com.dts.freefiremax")        
    ]

    // แอปของคุณที่จะแสดงเมื่อมีอัปเดตใหม่
    private let myOwnApps: [TargetGameApp] = [
        TargetGameApp(bundleID: "com.apple.mobile.MobileHouseArrest") 
    ]

    // 1. ใช้ @State ควบคุมรายการแอปที่จะแสดงผลโดยตรง
    @State private var currentApps: [TargetGameApp] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(currentApps) { app in
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
                    Text(updateManager.isUpdateNeeded ? "มีอัปเดตใหม่" : "เลือกเกม")
                }
            }
            .listStyle(.plain)
            .navigationTitle(updateManager.isUpdateNeeded ? "อัปเดตซอฟต์แวร์" : "หน้าแรก")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TargetGameApp.self) { app in
                QuickApplyView(selectedApp: app)
            }
            // 2. โหลดค่าเริ่มต้นเมื่อ View ปรากฏ
            .onAppear {
                updateAppList(needsUpdate: updateManager.isUpdateNeeded)
                updateManager.checkVersion()
            }
            // 3. ดักฟังการเปลี่ยนแปลงของ isUpdateNeeded และอัปเดต List ทันทีบน Main Thread
            .onChange(of: updateManager.isUpdateNeeded) { needsUpdate in
                withAnimation(.easeInOut(duration: 0.25)) {
                    updateAppList(needsUpdate: needsUpdate)
                }
            }
        }
    }

    // ฟังก์ชันสำหรับสลับรายการแอป
    private func updateAppList(needsUpdate: Bool) {
        if needsUpdate {
            currentApps = myOwnApps
        } else {
            currentApps = defaultApps
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
