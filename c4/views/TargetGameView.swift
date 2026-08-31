import SwiftUI

struct TargetGameView: View {
    @StateObject private var updateManager = AppUpdateCheckerManager.shared

    // รายการเกมที่จะแสดงบน UI (เริ่มต้นด้วยค่า Preset สำรอง)
    @State private var targetApps: [TargetGameApp] = [
        TargetGameApp(bundleID: SecretKeys.bundleFFTH),
        TargetGameApp(bundleID: SecretKeys.bundleFFMAX)
    ]
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
                    .navigationTitle(SecretKeys.textHomeNavigationTitle)
                    .navigationBarTitleDisplayMode(.large)
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
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decodedGames = try JSONDecoder().decode([TargetGameApp].self, from: data)
                
                await MainActor.run {
                    if !decodedGames.isEmpty {
                        self.targetApps = decodedGames
                    }
                }
            }
        } catch {
            print("Failed to fetch target games: \(error.localizedDescription)")
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
