import SwiftUI

struct EmptyStateView: View {
    var iconName: String = SecretKeys.iconEmptyState
    var title: String = SecretKeys.textNoPatchesFound

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(title)
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
        EmptyStateView()
            .navigationTitle("Target Games")
    }
}
