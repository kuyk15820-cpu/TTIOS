import SwiftUI

struct EmptyStateView: View {
    // 🟢 Enum สำหรับแบ่งประเภทการแสดงผลตามสถานะต่างๆ
    enum EmptyType {
        case noGames                               // ไม่พบรายการเกม
        case noPatches                             // ไม่พบรายการ Patch
        case custom(icon: String, title: String)   // กำหนด Icon และ Title เอง

        var iconName: String {
            switch self {
            case .noGames:
                return SecretKeys.iconNoGame
            case .noPatches:
                return SecretKeys.iconEmptyState
            case .custom(let icon, _):
                return icon
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
            Image(systemName: type.iconName)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
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
