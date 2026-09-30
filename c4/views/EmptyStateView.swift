import SwiftUI
import Lottie

struct EmptyStateView: View {
    // 🟢 Enum สำหรับแบ่งประเภทการแสดงผลตามสถานะต่างๆ
    enum EmptyType {
        case noGames                                    // ไม่พบรายการเกม
        case noPatches                                  // ไม่พบรายการ Patch
        case custom(animationName: String, title: String) // กำหนดชื่อไฟล์ Lottie (.json) และ Title เอง

        /// คืนค่าชื่อไฟล์ Lottie (.json) ใน Bundle
        var animationName: String {
            switch self {
            case .noGames:
                return SecretKeys.iconNoGame       // ชื่อไฟล์ .json สำหรับหน้า No Games (เช่น "no_games_anim")
            case .noPatches:
                return SecretKeys.iconEmptyState   // ชื่อไฟล์ .json สำหรับหน้า No Patches (เช่น "empty_state_anim")
            case .custom(let animationName, _):
                return animationName
            }
        }

        var title: String {
            switch self {
            case .noGames:
                return SecretKeys.textNoGamesFound
            case .noPatches:
                return SecretKeys.textNoPatchesFound
            case .custom(_, let title):
                return title
            }
        }
    }

    var type: EmptyType = .noPatches

    var body: some View {
        VStack(spacing: 12) {
            // 🟢 เล่นไฟล์ Lottie .json แบบ วนซ้ำ (Loop)
            LottieView(animation: .named(type.animationName))
                .playing(loopMode: .loop)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150) // กำหนดขนาดของแอนิเมชันตามต้องการ

            Text(type.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 🟢 ขยายพื้นที่คำนวณไปถึง Safe Area เพื่อให้อยู่กึ่งกลางหน้าจอจริง ไม่โดน Navigation Bar ดันลงมา
        .ignoresSafeArea(.container, edges: .top)
    }
}

#Preview {
    NavigationStack {
        EmptyStateView(type: .noGames)
            .navigationTitle("Target Games")
    }
}
