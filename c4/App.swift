import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    
    @State private var showOnboarding = false 
    @State private var showAttribution = false
    @State private var isCheckingUpdate = true // State สำหรับคุมการแสดง Splash Screen
    @Environment(\.scenePhase) private var scenePhase

    init() {
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
                    .opacity((showOnboarding || isCheckingUpdate) ? 0 : 1)
                    .allowsHitTesting(!showOnboarding && !isCheckingUpdate)

                // 2. หน้า Onboarding
                if showOnboarding {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                        appState.detectSupport()
                        performUpdateCheck()
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
                }

                // 3. หน้า Splash Screen (พื้นหลังดำ + Spinner หมุนรอเช็คเวอร์ชัน)
                if isCheckingUpdate && !showOnboarding {
                    AppSplashScreenView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: !showOnboarding && !isCheckingUpdate)
            .sheet(isPresented: $showAttribution) {
                DisplayAttributionSheet()
            }
            .onAppear {
                if !showOnboarding {
                    appState.detectSupport()
                    performUpdateCheck()
                }
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, !showOnboarding else { return }
                appState.detectSupport()
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }

        // MARK: - Helper Function เช็คเวอร์ชันพร้อมหน่วงเวลา Splash Screen 1 วินาที
    private func performUpdateCheck() {
        isCheckingUpdate = true
        let startTime = Date() // บันทึกเวลาเริ่มต้น
        
        AppUpdateCheckerManager.shared.checkVersion { needsUpdate, downloadUrl, releaseNotes, serverVersion in
            Task { @MainActor in
                // คำนวณเวลาที่ใช้ไป
                let elapsedTime = Date().timeIntervalSince(startTime)
                let minDuration: TimeInterval = 1.0 // กำหนดเวลาขั้นต่ำ 1 วินาที
                
                // ถ้าเช็คเสร็จเร็วกว่า 1 วินาที ให้สั่ง sleep รอจนครบเวลา
                if elapsedTime < minDuration {
                    let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: remainingTime)
                }
                
                // ปิด Splash Screen ด้วย Animation Fade Out
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isCheckingUpdate = false
                }
                
                // แสดงหน้า Update UI ถ้ามีเวอร์ชันใหม่
                if needsUpdate {
                    AppUpdateCheckerManager.shared.presentUpdateUI(
                        downloadUrl: downloadUrl,
                        releaseNotes: releaseNotes,
                        versionString: serverVersion
                    )
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
