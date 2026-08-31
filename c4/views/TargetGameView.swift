import SwiftUI
import Network

struct TargetGameView: View {
    @StateObject private var updateManager = AppUpdateCheckerManager.shared

    // เริ่มต้นเป็น Array ว่าง (ดึงข้อมูล Dynamic จาก Server)
    @State private var targetApps: [TargetGameApp] = []
    @State private var isLoading = false

    // 🟢 ตัว Monitor สำหรับตรวจจับการเชื่อมต่ออินเทอร์เน็ต
    @State private var networkMonitor: NWPathMonitor?

    // 🟢 URL สำหรับดึงรายชื่อ Target Game จาก Server (ดึงผ่าน SecretKeys.targetGamesURL)
    private let targetGamesURL = URL(string: SecretKeys.targetGamesURL)

    var body: some View {
        Group {
            if updateManager.isUpdateNeeded {
                // 🟢 ถ้ามีอัปเดต ให้แสดงหน้า AppUpdateView ดีไซน์เต็มหน้า
                AppUpdateView(
                    downloadUrl: updateManager.downloadUrl,
                    releaseNotes: updateManager.releaseNotes,
                    versionString: updateManager.serverVersion
                )
            } else {
                // 🔵 ถ้าไม่มีอัปเดต แสดงรายการเลือกเกมปกติ
                NavigationStack {
                    Group {
                        if isLoading {
                            // ขณะกำลังโหลดข้อมูล -> ซ่อน List ทั้งหมด
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if targetApps.isEmpty {
                            // โหลดเสร็จแล้วแต่ไม่มีรายการเกม -> แสดง Empty State
                            VStack(spacing: 12) {
                                Image(systemName: SecretKeys.iconEmptyState)
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text(SecretKeys.textNoPatchesFound)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // มีรายการเกม -> แสดง List
                            List {
                                Section {
                                    ForEach(targetApps) { app in
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
                    .toolbar {
                        // 🟢 ปุ่มรีเฟรชที่มุมขวาบน (ส่ง showHUD: true เพื่อแสดง HUD ตอนกดรีเฟรชเอง)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                Task {
                                    await fetchTargetGames(showHUD: true)
                                }
                            } label: {
                                Image(systemName: SecretKeys.iconRefresh)
                            }
                            .disabled(isLoading)
                            .accessibilityLabel(SecretKeys.textAccessibilityRefresh)
                        }
                    }
                    .navigationDestination(for: TargetGameApp.self) { app in
                        QuickApplyView(selectedApp: app)
                    }
                }
            }
        }
        .onAppear {
            updateManager.checkVersion()
            Task {
                // 🟢 โหลดข้อมูลเมื่อเปิดหน้าจอขึ้นมา (showHUD เป็น false โดยดีฟอลต์)
                await fetchTargetGames()
            }
            // 🟢 เริ่มต้นตรวจจับสถานะเครือข่าย
            startNetworkMonitoring()
        }
        .onDisappear {
            // 🟢 ปิด Monitor เมื่อออกจากหน้า เพื่อคืนทรัพยากร
            stopNetworkMonitoring()
        }
    }

    // MARK: - Network Monitoring Logic

    private func startNetworkMonitoring() {
        stopNetworkMonitoring()
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                Task { @MainActor in
                    // 🟢 เมื่อเน็ตต่อติด และรายการเกมยังว่างอยู่ ให้โหลดข้อมูลให้อัตโนมัติทันที
                    if self.targetApps.isEmpty && !self.isLoading {
                        await self.fetchTargetGames(showHUD: false)
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

    // MARK: - Fetch Dynamic Games from Server

    private func fetchTargetGames(showHUD: Bool = false) async {
        guard let url = targetGamesURL else { return }
        
        await MainActor.run {
            self.isLoading = true
            if showHUD {
                HUDHelper.show(message: "")
            }
        }

        let startTime = Date()

        do {
            var request = URLRequest(
                url: url,
                // ป้องกันการดึงข้อมูลจาก Cache ทั้งฝั่ง Local และ Remote
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 15
            )
            request.httpMethod = "GET"
            request.setValue(SecretKeys.userAgentValue, forHTTPHeaderField: SecretKeys.userAgentHeader)

            // ใช้ URLSession.pinned เพื่อความปลอดภัยผ่าน SSL Pinning Delegate
            let (data, response) = try await URLSession.pinned.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let decodedGames = try JSONDecoder().decode([TargetGameApp].self, from: data)
                
                // 🟢 กรองเอาเฉพาะเกมที่ active != false (ถ้าไม่ได้ส่งมาจะถือว่าเป็น true)
                let activeGames = decodedGames.filter { $0.active ?? true }
                
                await MainActor.run {
                    self.targetApps = activeGames
                }
            } else {
                // หาก Status Code ไม่สำเร็จ ให้ล้างข้อมูลออก
                await MainActor.run {
                    self.targetApps = []
                }
            }
        } catch {
            print("Failed to fetch target games: \(error.localizedDescription)")
            // หากเกิด Error (เช่น ปิดเน็ต/ไม่มีสัญญาณ) ให้ล้างข้อมูลเพื่อให้แสดง Empty State
            await MainActor.run {
                self.targetApps = []
            }
        }

        // หากมีการแสดง HUD ให้การันตีการแสดงอย่างน้อย 1.0 วินาที เพื่อความสม่ำเสมอของ UI
        if showHUD {
            let elapsedTime = Date().timeIntervalSince(startTime)
            let minDuration: TimeInterval = 1.0
            if elapsedTime < minDuration {
                let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: remainingTime)
            }
        }

        await MainActor.run {
            self.isLoading = false
            if showHUD {
                HUDHelper.hide()
            }
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
