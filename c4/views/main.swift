import SwiftUI

struct MainContainerView: View {
    // 🟢 กำหนด State สำหรับคุมการสลับหน้า (0 = WebView, 1 = TargetGameView)
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. หน้าแรก: Web View เต็มจอ
            FullScreenWebView()
                .tag(0)
                .ignoresSafeArea() // ให้ Web View ชิดขอบทุกด้าน

            // 2. หน้าที่สอง: TargetGameView (ปัดขวามาเจอ)
            TargetGameView()
                .tag(1)
        }
        // 🟢 เปลี่ยนสไตล์ให้รองรับการปัดซ้าย-ขวาแบบ Page View
        .tabViewStyle(.page(indexDisplayMode: .never)) // ปิดจุดบอกหน้าขอบล่าง (หรือใช้ .always ถ้าอยากให้เห็นจุด)
        .ignoresSafeArea()
    }
}

#Preview {
    MainContainerView()
        .environmentObject(AppState())
}
