import SwiftUI

struct AppUpdateView: View {
    // ข้อมูลที่รับมาจาก AppUpdateStreamManager หรือ Server
    let downloadUrl: String?
    let releaseNotes: String?
    let versionString: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var isNotesExpanded: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // MARK: - Header Top Section (Purple Gradient)
                    VStack(spacing: 16) {
                        // Top Bar Menu
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("แอป")
                                        .font(.system(size: 17))
                                }
                                .foregroundColor(.white)
                            }

                            Spacer()

                            Button(action: {
                                // Share Action
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // App Icon
                        Image(systemName: "moon.stars.fill") // เปลี่ยนเป็น Image("AppIcon") ของคุณได้
                            .resizable()
                            .scaledToFit()
                            .padding(25)
                            .frame(width: 140, height: 140)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.15, green: 0.10, blue: 0.30), Color(red: 0.35, green: 0.25, blue: 0.60)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(Color(red: 0.9, green: 0.85, blue: 1.0))
                            .cornerRadius(28)
                            .shadow(color: .purple.opacity(0.3), radius: 15, x: 0, y: 8)
                            .padding(.top, 10)

                        // App Title
                        Text("FXTool: Game Mod\n& Helper Framework")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        // Action Buttons (ติดตั้ง / ส่งคำติชม)
                        HStack(spacing: 12) {
                            // ปุ่มติดตั้ง (Install)
                            Button(action: {
                                if let urlStr = downloadUrl, let url = URL(string: urlStr) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("ติดตั้ง")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.white.opacity(0.25))
                                    .cornerRadius(12)
                            }

                            // ปุ่มส่งคำติชม (Feedback)
                            Button(action: {
                                // Feedback Logic
                            }) {
                                Text("ส่งคำติชม")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 25)
                    }
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.18, blue: 0.38),
                                Color(red: 0.12, green: 0.10, blue: 0.22),
                                Color.black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // MARK: - Info Card Grid (นักพัฒนา / หมดอายุ / เวอร์ชั่น)
                    VStack(alignment: .leading, spacing: 20) {
                        
                        HStack(spacing: 0) {
                            // Developer Info
                            VStack(spacing: 6) {
                                Text("นักพัฒนา")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.gray)
                                Text("The Genesis")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .background(Color.white.opacity(0.15))
                                .frame(height: 45)

                            // Days Remaining
                            VStack(spacing: 4) {
                                Text("หมดอายุ")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text("90")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("วัน")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .background(Color.white.opacity(0.15))
                                .frame(height: 45)

                            // Version Info
                            VStack(spacing: 4) {
                                Text("เวอร์ชั่น")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text(versionString)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("รุ่น 2026")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                        .background(Color(white: 0.12))
                        .cornerRadius(14)

                        // MARK: - สิ่งที่ต้องทดสอบ (Release Notes / Testing Notes)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("สิ่งที่ต้องทดสอบ")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(releaseNotes ?? "ไม่มีรายละเอียดการอัปเดต")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.85))
                                    .lineLimit(isNotesExpanded ? nil : 3)
                                
                                if !(releaseNotes?.isEmpty ?? true) {
                                    Button(action: {
                                        withAnimation {
                                            isNotesExpanded.toggle()
                                        }
                                    }) {
                                        Text(isNotesExpanded ? "ย่อลง" : "เพิ่มเติม")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.12))
                            .cornerRadius(14)
                        }

                        // MARK: - คำอธิบายแอป (App Description)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("คำอธิบายแอป")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Text("FXTool Framework system utility for internal build management and versioning controls.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 0.85))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(white: 0.12))
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
        }
    }
}
