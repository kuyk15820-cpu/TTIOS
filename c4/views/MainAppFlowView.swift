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
                // ถ้ายังไม่มี Key หรือ Key ถูกลบ/ไม่ผ่าน -> แสดงหน้า Login
                LicenseLoginView()
            } else {
                // ถ้ามี Key และผ่านการยืนยันแล้ว -> เข้าสู่หน้า TargetGameView
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
                await MainActor.run {
                    isCheckingKey = false
                }
                return
            }

            // 2. ถ้ามี Key บันทึกไว้ ให้ยิงไปเช็กความถูกต้องกับ Server
            if !savedKey.isEmpty {
                let result = try await LicenseManager.shared.verifyKey(savedKey)
                
                // ตรวจสอบทั้ง status == false, daysLeft < 0 หรือ forceExit == true
                let isInvalid = !result.status || (result.daysLeft ?? 0) < 0 || (result.forceExit == true)
                
                if isInvalid {
                    // ล้าง Key บน Main Thread เพื่อให้ UI เปลี่ยนหน้าไป Login ทันที
                    await MainActor.run {
                        LicenseManager.shared.savedKey = nil
                        savedKey = ""
                    }
                }
            }
        } catch {
            print("Init Error: \(error.localizedDescription)")
            // หมายเหตุ: กรณีออฟไลน์/เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ หากต้องการให้บังคับล็อกอินใหม่เมื่อไม่มีเน็ต
            // ให้ปลดล็อกคอมเมนต์ด้านล่างนี้ได้ครับ:
            /*
            await MainActor.run {
                LicenseManager.shared.savedKey = nil
                savedKey = ""
            }
            */
        }
        
        // สลับสถานะ Loading บน Main Thread
        await MainActor.run {
            isCheckingKey = false
        }
    }
}
