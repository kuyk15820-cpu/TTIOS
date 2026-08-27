import SwiftUI

struct TargetGameView: View {
    private let targetApps: [TargetGameApp] = [
        TargetGameApp(bundleID: "com.dts.freefireth"),
        TargetGameApp(bundleID: "com.dts.freefiremax")        
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(targetApps) { app in
                        NavigationLink(value: app) {
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(uiImage: icon)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "app.window.checkmark")
                                        .font(.title2)
                                        .foregroundStyle(Color.primary)
                                }

                                Text(app.name)
                                    .font(.headline)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    Text("เลือกเกม")
                }
            }
            .listStyle(.plain)
            .navigationTitle("หน้าแรก")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TargetGameApp.self) { app in
                QuickApplyView(selectedApp: app)
            }
        }
    }
}

#Preview {
    TargetGameView()
        .environmentObject(AppState())
}
