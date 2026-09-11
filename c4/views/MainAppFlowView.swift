import SwiftUI

struct MainAppFlowView: View {
    @State private var isCheckingInit: Bool = true
    
    // Alert State
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var shouldExitOnAlertDismiss: Bool = false

    var body: some View {
        Group {
            if isCheckingInit {
                // หน้า Loading สั้นๆ เช็กสถานะเซิร์ฟเวอร์
                ZStack {
                    Color(red: 0.07, green: 0.07, blue: 0.07)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("Connecting...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // เปิดเข้าหน้า Login เมื่อตรวจสอบผ่าน
                LicenseLoginView()
            }
        }
        .task {
            await checkServerInit()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if shouldExitOnAlertDismiss {
                    exit(0)
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func checkServerInit() async {
        do {
            let initData = try await LicenseManager.shared.checkInit()
            
            // 🟢 1. กรณี Package ถูกลบ / ไม่ถูกต้อง
            if initData.forceExit == true {
                presentAlert(
                    title: "System Error",
                    message: initData.message ?? "Package ไม่ถูกต้องหรือถูกลบแล้ว",
                    shouldExit: true
                )
                return
            }
            
            // 🟢 2. กรณีระบบปิดปรับปรุง (Maintenance Mode)
            if LicenseManager.shared.isMaintenance {
                presentAlert(
                    title: "Maintenance",
                    message: "ระบบกำลังปิดปรับปรุงชั่วคราว กรุณาลองใหม่อีกครั้งในภายหลัง",
                    shouldExit: true
                )
                return
            }
            
            // ผ่านการตรวจสอบ -> เข้าหน้า Login
            await MainActor.run {
                isCheckingInit = false
            }
            
        } catch {
            print("Init Error: \(error.localizedDescription)")
            // 🟢 3. กรณีเชื่อมต่อ Server ไม่ได้
            presentAlert(
                title: "Connection Error",
                message: "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต",
                shouldExit: false
            )
            
            await MainActor.run {
                isCheckingInit = false
            }
        }
    }
    
    private func presentAlert(title: String, message: String, shouldExit: Bool = false) {
        Task { @MainActor in
            self.alertTitle = title
            self.alertMessage = message
            self.shouldExitOnAlertDismiss = shouldExit
            self.showAlert = true
        }
    }
}
