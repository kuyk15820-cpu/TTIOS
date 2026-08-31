import SwiftUI

struct TargetGameView: View {
    @StateObject private var updateManager = AppUpdateCheckerManager.shared

    // เริ่มต้นเป็น Array ว่าง (ดึงข้อมูล Dynamic จาก Server)
    @State private var targetApps: [TargetGameApp] = []
    @State private var isLoading = false

    // URL สำหรับดึงรายชื่อ Target Game จาก Server
    private let targetGamesURL = URL(string: "https://\(SecretKeys.hostDomain)/patches/games.json")

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
                        // 🟢 ปุ่มรีเฟรชที่มุมขวาบน
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                Task {
                                    await fetchTargetGames()
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
                    .refreshable {
                        await fetchTargetGames()
                    }
                }
            }
        }
        .onAppear {
            updateManager.checkVersion()
            Task {
                await fetchTargetGames()
            }
        }
    }

    // MARK: - Fetch Dynamic Games from Server

    private func fetchTargetGames() async {
        guard let url = targetGamesURL else { return }
        
        await MainActor.run {
            self.isLoading = true
            HUDHelper.show(message: "")
        }

        let startTime = Date()

        do {
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.httpMethod = "GET"
            request.setValue(SecretKeys.userAgentValue, forHTTPHeaderField: SecretKeys.userAgentHeader)

            // 🟢 เปลี่ยนมาใช้ URLSession.pinned เพื่อความปลอดภัยผ่าน SSL Pinning Delegate
            let (data, response) = try await URLSession.pinned.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let decodedGames = try JSONDecoder().decode([TargetGameApp].self, from: data)
                
                await MainActor.run {
                    self.targetApps = decodedGames
                }
            }
        } catch {
            print("Failed to fetch target games: \(error.localizedDescription)")
        }

        // การันตีการแสดง HUD อย่างน้อย 1.0 วินาที เพื่อให้ประสบการณ์ผู้ใช้งานสม่ำเสมอ
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minDuration: TimeInterval = 1.0
        if elapsedTime < minDuration {
            let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remainingTime)
        }

        await MainActor.run {
            self.isLoading = false
            HUDHelper.hide()
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
