import SwiftUI

struct MainAppFlowView: View {
    @State private var isCheckingInit: Bool = true

    var body: some View {
        Group {
            if isCheckingInit {
                // หน้า Loading สั้นๆ เช็กสถานะเซิร์ฟเวอร์
                ZStack {
                    Color(red: 0.07, green: 0.07, blue: 0.07)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            } else {
                // เปิดเข้าหน้า Login ทุกครั้ง
                LicenseLoginView()
            }
        }
        .task {
            await checkServerInit()
        }
    }

    private func checkServerInit() async {
        do {
            // เช็กแค่ระบบปรับปรุงหรือ Force Exit หรือไม่
            let initData = try await LicenseManager.shared.checkInit()
            
            if initData.forceExit == true {
                exit(0)
            }
        } catch {
            print("Init Error: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isCheckingInit = false
        }
    }
}
