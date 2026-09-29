import SwiftUI
import UIKit
import Network

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    
    // 🟢 ดึง AppUpdateCheckerManager มาคุม State ระดับ Root App
    @StateObject private var updateManager = AppUpdateCheckerManager.shared
    
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    
    @State private var showOnboarding = false 
    @State private var isCheckingUpdate = true // เริ่มต้นเป็น true เพื่อแสดง Splash Screen
    @Environment(\.scenePhase) private var scenePhase

    // ตัว Monitor ดักจับสถานะการเชื่อมต่ออินเทอร์เน็ต
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")

    init() {
        LayoutMetricsHelper.shared.applyLayoutConstraints()
        setupLogCapture()
        log("app: c4 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1. หน้าหลักของแอป
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .opacity(isCheckingUpdate ? 0 : 1)
                    .allowsHitTesting(!showOnboarding && !isCheckingUpdate && !updateManager.isUpdateNeeded)

                // 2. 🟢 หน้า Force Update (ถ้าต้องอัปเดต จะเด้งทับทันทีไม่ว่าจะอยู่หน้าไหน/เมนูไหน)
                if updateManager.isUpdateNeeded && !isCheckingUpdate {
                    AppUpdateView(
                        downloadUrl: updateManager.downloadUrl,
                        releaseNotes: updateManager.releaseNotes,
                        versionString: updateManager.serverVersion
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(998)
                }

                // 3. หน้า Splash Screen (แสดงผลค้างไว้จนกว่าจะเช็คเวอร์ชันสำเร็จ)
                if isCheckingUpdate {
                    AppSplashScreenView()
                        .transition(.opacity)
                        .zIndex(999)
                }

                // 4. หน้า Onboarding (แสดงผลหลังจากปิด Splash Screen หากยังตั้งค่าไม่เสร็จ)
                if showOnboarding && !isCheckingUpdate && !updateManager.isUpdateNeeded {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1000)
                }
            }
            .onAppear {
                isCheckingUpdate = true
                appState.detectSupport()
                startNetworkMonitoring()
            }
            // 🟢 ดักจับตอนสลับแอปกลับเข้ามา (Background -> Foreground)
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                
                // หากปิด Splash Screen แล้ว ให้แอบเช็คเวอร์ชันใหม่เงียบๆ
                if !isCheckingUpdate {
                    updateManager.checkVersion()
                }
                
                appState.detectSupport()
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }

    // MARK: - Network Monitoring Logic
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    if self.isCheckingUpdate {
                        self.performUpdateCheck()
                    } else {
                        // 🟢 ถ้าเน็ตเชื่อมต่อตอนกำลังใช้งาน ให้แอบเช็คเวอร์ชัน
                        self.updateManager.checkVersion()
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Helper Function เช็คเวอร์ชันพร้อมหน่วงเวลา Splash Screen ขั้นต่ำ 1 วินาที
    private func performUpdateCheck() {
        let startTime = Date()
        
        AppUpdateCheckerManager.shared.checkVersion { needsUpdate, downloadUrl, releaseNotes, serverVersion in
            Task { @MainActor in
                if serverVersion.isEmpty && !needsUpdate && downloadUrl == nil {
                    return 
                }

                let elapsedTime = Date().timeIntervalSince(startTime)
                let minDuration: TimeInterval = 1.0
                
                if elapsedTime < minDuration {
                    let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: remainingTime)
                }
                
                self.networkMonitor.cancel()
                
                // ปิด Splash Screen เพื่อเปิดหน้าแอป
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isCheckingUpdate = false
                }
            }
        }
    }
}

// MARK: - AppState
class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}
