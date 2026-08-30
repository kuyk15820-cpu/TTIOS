import SwiftUI

struct TargetGameView: View {
    @StateObject private var updateManager = AppUpdateCheckerManager.shared

    private let defaultApps: [TargetGameApp] = [
        TargetGameApp(bundleID: SecretKeys.bundleFFTH),
        TargetGameApp(bundleID: SecretKeys.bundleFFMAX)        
    ]

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
                            ForEach(defaultApps) { app in
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
                }
            }
        }
        .onAppear {
            updateManager.checkVersion()
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
