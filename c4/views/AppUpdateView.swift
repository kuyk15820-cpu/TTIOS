import SwiftUI

struct AppUpdateView: View {
    let downloadUrl: String?
    let releaseNotes: String?
    let versionString: String

    // ดึง Manager มาเพื่ออ่านค่า downloadProgress และ isDownloading
    @ObservedObject private var manager = AppUpdateCheckerManager.shared

    // State สำหรับควบคุมคำว่า "Done"
    @State private var isCompleted: Bool = false

    var body: some View {
        ZStack {
            // Background ดำสนิท + Subtle Ambient Glow ด้านบน
            Color.black.ignoresSafeArea()
            
            GeometryReader { proxy in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.12), Color.blue.opacity(0.05), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.7
                        )
                    )
                    .frame(width: proxy.size.width * 1.4, height: proxy.size.width * 1.4)
                    .offset(x: proxy.size.width * 0.1, y: -proxy.size.width * 0.3)
                    .blur(radius: 40)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Main Content Area (Scrollable / Centered)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // App Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.25, green: 0.55, blue: 0.98), Color(red: 0.12, green: 0.35, blue: 0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 76, height: 76)
                                .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)

                            Image(systemName: "globe.asia.australia.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 42, height: 42)
                                .foregroundColor(.white)
                        }

                        // Headline & Description
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Update your\napplication to the\nlatest version")
                                .font(.system(size: 30, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .lineSpacing(4)

                            Text(releaseNotes?.isEmpty == false ? releaseNotes! : "A brand new version of the app is available. Please update your app to use all of our amazing features.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(white: 0.65))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                }

                Spacer()

                // MARK: - Bottom Action Bar (Animated Download Button)
                VStack {
                    Button(action: {
                        // กดปุ่มได้เฉพาะตอนไม่ได้อยู่ในสถานะกำลังโหลด หรือแสดงคำว่า Done
                        guard !manager.isDownloading, !isCompleted else { return }
                        
                        if let urlStr = downloadUrl {
                            manager.startDownload(from: urlStr)
                        }
                    }) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // 1. แถบสีขาวที่วิ่งเติมจากซ้ายไปขวาตาม Progress
                                RoundedRectangle(cornerRadius: 26)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * CGFloat(manager.downloadProgress))
                                    .animation(.easeInOut(duration: 0.2), value: manager.downloadProgress)

                                // 2. ข้อความบนปุ่ม (ปรับสีตัวอักษรและข้อความตามสถานะ)
                                Text(buttonTitle)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(manager.downloadProgress > 0.5 ? .black : .white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(height: 52)
                        .background(Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                    }
                    .disabled(manager.isDownloading || isCompleted)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
        }
        // คอยตรวจจับเมื่อดาวน์โหลดเสร็จสมบูรณ์ (Progress ถึง 1.0 หรือ 100%)
        .onChange(of: manager.downloadProgress) { progress in
            if progress >= 1.0 {
                withAnimation {
                    isCompleted = true
                }
                
                // ค้างคำว่า "Done" ไว้ 1.5 วินาที แล้วรีเซ็ตกลับเป็นปกติ
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isCompleted = false
                        manager.downloadProgress = 0.0
                    }
                }
            }
        }
    }

    // MARK: - Dynamic Button Title Helper
    private var buttonTitle: String {
        if isCompleted {
            return "Done"
        } else if manager.isDownloading {
            let percentage = Int(manager.downloadProgress * 100)
            return "Downloading... \(percentage)%"
        } else {
            return "Update now"
        }
    }
}
