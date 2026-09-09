import SwiftUI

struct MainContainerView: View {
    // 🟢 กำหนด State สำหรับคุมการสลับหน้า (0 = WebView, 1 = TargetGameView)
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. หน้าแรก: Web View ให้ทะลุ Safe Area เต็มจอเฉพาะหน้านี้
            FullScreenWebView()
                .tag(0)
                .ignoresSafeArea() // 🟢 ชิดขอบเต็มจอเฉพาะหน้า Web

            // 2. หน้าที่สอง: TargetGameView ปล่อยให้เว้น Safe Area ตามปกติ (ไม่ใส่ ignoresSafeArea)
            TargetGameView()
                .tag(1)
        }
        // 🟢 เปลี่ยนสไตล์เป็น Paging
        .tabViewStyle(.page(indexDisplayMode: .never))
        // 🔴 เอา .ignoresSafeArea() บรรทัดล่างสุดนี้ออก เพื่อไม่ให้กระทบตำแหน่งของ TargetGameView
    }
}

#Preview {
    MainContainerView()
        .environmentObject(AppState())
}
