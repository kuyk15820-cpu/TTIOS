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

    @State private var currentApps: [TargetGameApp] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(currentApps) { app in
                        if updateManager.isUpdateNeeded {
                            // 🟢 โหมดอัปเดต: กดแล้วสั่งเริ่มดาวน์โหลดไฟล์
                            Button {
                                if !updateManager.isDownloading, let downloadUrl = updateManager.downloadUrl {
                                    updateManager.startDownload(from: downloadUrl)
                                }
                            } label: {
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
                                        .foregroundStyle(Color.primary)

                                    Spacer()

                                    // แสดง Spinner ด้านขวาขณะกำลังดาวน์โหลด
                                    if updateManager.isDownloading {
                                        ActivityIndicator(isAnimating: true, style: .medium)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .disabled(updateManager.isDownloading)
                        } else {
                            // 🔵 โหมดปกติ: ไปยังหน้า QuickApplyView
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
                    }
                } header: {
                    Text(updateManager.isUpdateNeeded ? "มีอัปเดตใหม่" : "เลือกเกม")
                }
            }
            .listStyle(.plain)
            .navigationTitle(updateManager.isUpdateNeeded ? "c4" : "หน้าแรก")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TargetGameApp.self) { app in
                QuickApplyView(selectedApp: app)
            }
            .onAppear {
                updateAppList(needsUpdate: updateManager.isUpdateNeeded)
                updateManager.checkVersion()
            }
            .onChange(of: updateManager.isUpdateNeeded) { needsUpdate in
                withAnimation(.easeInOut(duration: 0.25)) {
                    updateAppList(needsUpdate: needsUpdate)
                }
            }
        }
    }

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
