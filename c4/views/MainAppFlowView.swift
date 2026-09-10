import SwiftUI

struct MainAppFlowView: View {
    // โหลดสถานะ Key จาก UserDefaults
    @AppStorage("saved_license_key") private var savedKey: String = ""
    @State private var isCheckingKey: Bool = true

    var body: some View {
        Group {
            if isCheckingKey {
                // หน้า Splash / Loading สั้นๆ ขณะตรวจเช็ก Init & Saved Key
                ZStack {
                    Color(red: 0.07, green: 0.07, blue: 0.07)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            } else if savedKey.isEmpty {
                // ถ้ายังไม่มี Key หรือ Key ไม่ผ่าน -> แสดงหน้า Login
                LicenseLoginView()
            } else {
                // ถ้ามี Key แล้ว -> เข้าสู่หน้า TargetGameView
                TargetGameView()
            }
        }
        .animation(.default, value: savedKey)
        .task {
            await validateInitialState()
        }
    }

    private func validateInitialState() async {
        do {
            // 1. เรียก API Init เช็ก Maintenance
            let initData = try await LicenseManager.shared.checkInit()
            
            if initData.forceExit == true {
                exit(0)
            }
            
            if initData.maintenance == true {
                // ระบบปิดปรับปรุง
                return
            }

            // 2. ถ้ามี Key บันทึกไว้ ให้ยิงไปเช็กความถูกต้องกับ Server
            if !savedKey.isEmpty {
                let result = try await LicenseManager.shared.verifyKey(savedKey)
                if !result.status || (result.daysLeft ?? 0) < 0 {
                    // ถ้า Key หมดอายุหรือไม่ถูกต้อง ให้ล้าง Key ออกเพื่อกลับไปหน้า Login
                    LicenseManager.shared.savedKey = nil
                    savedKey = ""
                }
            }
        } catch {
            print("Init Error: \(error.localizedDescription)")
        }
        
        isCheckingKey = false
    }
}

// MARK: - Preview
#Preview {
    MainAppFlowView()
        .environmentObject(AppState())
}
