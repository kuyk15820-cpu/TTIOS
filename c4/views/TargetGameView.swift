import SwiftUI
import Network

struct TargetGameView: View {
    // 🟢 ดึงข้อมูลผ่าน TargetGameManager.shared
    @StateObject private var gameManager = TargetGameManager.shared

    // 🟢 ตรวจจับ สถานะการทำงานของแอป (Active, Inactive, Background)
    @Environment(\.scenePhase) private var scenePhase

    // 🟢 ตัว Monitor สำหรับตรวจจับการเชื่อมต่ออินเทอร์เน็ต
    @State private var networkMonitor: NWPathMonitor?

    var body: some View {
        NavigationStack {
            Group {
                if gameManager.targetApps.isEmpty {
                    if gameManager.isLoading {
                        // 🟢 กำลังโหลดครั้งแรกและยังไม่มีข้อมูล -> แสดงพื้นที่ว่างเปล่า (กันหน้า Empty State กระพริบ)
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 🟢 โหลดเสร็จแล้วแต่ไม่มีรายการเกมจริงๆ -> แสดง Empty State
                        EmptyStateView(type: .noGames)
                    }
                } else {
                    // 🟢 แสดง List เสมอ (ไม่ซ่อน List แม้กำลังเช็คข้อมูลเบื้องหลัง)
                    List {
                        Section {
                            ForEach(gameManager.targetApps) { app in
                                NavigationLink(value: app) {
                                    HStack(spacing: 12) {
                                        if let icon = app.icon {
                                            Image(uiImage: icon)
                                                .resizable()
                                                .frame(width: 32, height: 32)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(systemName: SecretKeys.iconAppWindowCheckmark)
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
                            Text(SecretKeys.textSelectGameSection)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(SecretKeys.textHomeNavigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TargetGameApp.self) { app in
                QuickApplyView(selectedApp: app)
            }
        }
        .onAppear {
            // 🟢 โหลดข้อมูลเบื้องหลังโดยไม่ขึ้น HUD (เนื่องจาก Pre-fetch มาแล้วจาก Splash Screen)
            gameManager.fetchTargetGames(showHUD: false)
            startNetworkMonitoring()
        }
        .onDisappear {
            stopNetworkMonitoring()
        }
        // 🟢 ตรวจจับเมื่อสลับแอปกลับเข้ามา (.active) แล้วดึงข้อมูลใหม่แบบเงียบๆ
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                gameManager.fetchTargetGames(showHUD: false)
            }
        }
    }

    // MARK: - Network Monitoring Logic

    private func startNetworkMonitoring() {
        stopNetworkMonitoring()
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                Task { @MainActor in
                    if self.gameManager.targetApps.isEmpty && !self.gameManager.isLoading {
                        self.gameManager.fetchTargetGames(showHUD: false)
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "TargetGameViewNetworkMonitor")
        monitor.start(queue: queue)
        self.networkMonitor = monitor
    }

    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
