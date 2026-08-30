import SwiftUI

struct AppUpdateView: View {
    // 💡 ดึง Manager เข้ามาคุม State การดาวน์โหลด
    @StateObject private var updateManager = AppUpdateCheckerManager.shared
    
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
                // MARK: - Main Content Area
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // App Icon (Full-bleed Frame)
                        ZStack {
                            if let icon = AppIconAssets.appIcon {
                                icon
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)
                            } else {
                                // Fallback กรณี Base64 ถอดรหัสไม่ได้
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
                                    .overlay(
                                        Image(systemName: SecretKeys.updateIconGlobe)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 42, height: 42)
                                            .foregroundColor(.white)
                                    )
                            }
                        }

                        // Headline & Description
                        VStack(alignment: .leading, spacing: 14) {
                            Text(SecretKeys.updateTitleText)
                                .font(.system(size: 30, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .lineSpacing(4)

                            Text(releaseNotes?.isEmpty == false ? releaseNotes! : SecretKeys.updateDefaultNotes)
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

                // MARK: - Bottom Action Bar
                VStack(spacing: 12) {
                    Button(action: {
                        if !updateManager.isDownloading && !updateManager.isDone, let urlStr = downloadUrl {
                            updateManager.startDownload(from: urlStr)
                        }
                    }) {
                        HStack(spacing: 10) {
                            if updateManager.isDownloading {
                                ActivityIndicator(isAnimating: true, style: .medium)
                                
                                Text(updateManager.downloadSizeText.isEmpty ? SecretKeys.updateBtnDownloadingDefault : updateManager.downloadSizeText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            } else if updateManager.isDone {
                                Text(SecretKeys.updateBtnDone)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            } else {
                                Text(SecretKeys.updateBtnNow)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                    }
                    .disabled(updateManager.isDownloading || updateManager.isDone)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
        }
    }
}
