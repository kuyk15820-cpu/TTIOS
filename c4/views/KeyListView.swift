import SwiftUI

struct KeyListView: View {
    @StateObject private var viewModel = KeyViewModel()
    
    // ตัวแปรสำหรับเลือก Filter (All, Active, Banned, Expired)
    @State private var selectedFilter: KeyFilter = .all
    
    // State สำหรับ Sheet หรือ Alert ในการสร้าง Key ใหม่
    @State private var showingCreateKeySheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Filter Picker
                Picker("Filter Keys", selection: $selectedFilter) {
                    ForEach(KeyFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // MARK: - Key List
                List {
                    ForEach(filteredKeys) { key in
                        KeyRowView(key: key, 
                                   onCopy: { viewModel.copyToClipboard(key: key.keyString) },
                                   onResetHWID: { viewModel.resetHWID(forKey: key.id) },
                                   onToggleBan: { viewModel.toggleBanStatus(forKey: key.id) })
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("License Keys")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateKeySheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingCreateKeySheet) {
                // เรียกใช้ View สำหรับสร้าง Key ใหม่
                Text("Create New Key Sheet")
            }
        }
    }

    // ฟังก์ชั่นกรองรายการ Key ตาม Filter ที่เลือก
    private var filteredKeys: [LicenseKey] {
        switch selectedFilter {
        case .all:
            return viewModel.keys
        case .active:
            return viewModel.keys.filter { $0.status == .active }
        case .banned:
            return viewModel.keys.filter { $0.status == .banned }
        case .expired:
            return viewModel.keys.filter { $0.status == .expired }
        }
    }
}

// MARK: - Enum สำหรับ Filter
enum KeyFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case banned = "Banned"
    case expired = "Expired"
}

// MARK: - Subview สำหรับแต่ละ Row ของ Key
struct KeyRowView: View {
    let key: LicenseKey
    let onCopy: () -> Void
    let onResetHWID: () -> Void
    let onToggleBan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Key String & ปุ่มคัดลอก
                Text(key.keyString)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()

                // Badge แสดงสถานะ
                StatusBadgeView(status: key.status)
            }

            // รายละเอียด Device / HWID และ วันหมดอายุ
            HStack {
                Label("\(key.devices.count) Devices", systemImage: "iphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Expires: \(key.formattedExpirationDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Action Buttons (Reset HWID / Ban-Unban)
            HStack {
                Button(action: onResetHWID) {
                    Label("Reset HWID", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.orange)

                Spacer()

                Button(action: onToggleBan) {
                    Label(key.status == .banned ? "Unban" : "Ban", 
                          systemImage: key.status == .banned ? "checkmark.seal" : "slash.circle")
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(key.status == .banned ? .green : .red)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge View
struct StatusBadgeView: View {
    let status: KeyStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(6)
    }

    private var backgroundColor: Color {
        switch status {
        case .active: return .green
        case .banned: return .red
        case .expired: return .gray
        }
    }
}
