import SwiftUI
import WebKit

struct FullScreenWebView: View {
    // 🟢 กำหนด URL หลักตรงนี้ได้เลย
    private let targetURL = URL(string: "https://chatgpt.com")!

    var body: some View {
        // 🟢 เพิ่ม NavigationStack ครอบเพื่อให้ Safe Area และ Layout ทำงานสมดุลกับ TargetGameView
        NavigationStack {
            InternalWebView(url: targetURL)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar) // ซ่อน Navigation Bar ไว้เพื่อให้แสดงเว็บได้เต็มพื้นที่
        }
    }
}

// MARK: - Internal WKWebView Component
private struct InternalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.bounces = false // ปิด Bouncing effect
        
        // โหลด URL ทันทีในขั้นตอนสร้าง View
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // ไม่ต้องอัปเดตอะไรเพิ่มเติมเนื่องจากกำหนด URL ตายตัวไว้แล้ว
    }
}

#Preview {
    FullScreenWebView()
}
