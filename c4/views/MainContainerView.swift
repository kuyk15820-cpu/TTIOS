import SwiftUI

struct MainContainerView: View {
    // 🟢 กำหนด State สำหรับคุมการสลับหน้า (0 = WebView, 1 = TargetGameView)
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. หน้าแรก: Web View (อยู่ในขอบเขต Safe Area ปกติ)
            FullScreenWebView()
                .tag(0)

            // 2. หน้าที่สอง: TargetGameView (อยู่ในขอบเขต Safe Area ปกติ)
            TargetGameView()
                .tag(1)
        }
        // 🟢 สไตล์การปัดเปลี่ยนหน้าแบบ Page View
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

#Preview {
    MainContainerView()
        .environmentObject(AppState())
}
