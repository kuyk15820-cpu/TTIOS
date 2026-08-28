import SwiftUI

struct AppUpdateView: View {
    let downloadUrl: String?
    let releaseNotes: String?
    let versionString: String

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
                Spacer()

                // MARK: - Main Content Container
                VStack(alignment: .leading, spacing: 28) {
                    
                    // App Icon (สี่เหลี่ยมโค้งมน Gradient สีฟ้า/น้ำเงิน)
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

                    // MARK: - Update Action Button (ปุ่มใส Capsule ขอบสีขาว)
                    Button(action: {
                        if let urlStr = downloadUrl, let url = URL(string: urlStr) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Update now")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
    }
}
