import SwiftUI

struct KeyListView: View {
    @StateObject private var viewModel = KeyViewModel()
    
    // Search Filter
    @State private var searchText = ""
    
    // Sheet States สำหรับ Actions ต่างๆ
    @State private var showCreateKeySheet = false
    @State private var selectedKeyForBan: LicenseKey? = nil
    @State private var selectedKeyForRenew: LicenseKey? = nil
    
    // Alert State สำหรับ Reset HWID Single & All
    @State private var showResetSingleAlert = false
    @State private var keyToReset: LicenseKey? = nil
    @State private var showResetAllAlert = false

    var filteredKeys: [LicenseKey] {
        if searchText.isEmpty {
            return viewModel.keys
        } else {
            return viewModel.keys.filter {
                $0.tokenCode.localizedCaseInsensitiveContains(searchText) ||
                ($0.pname?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.reason?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Tab Selection Bar
                Picker("Key Tab", selection: $viewModel.selectedTab) {
                    ForEach(KeyViewModel.KeyTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: viewModel.selectedTab) { _ in
                    Task { await viewModel.fetchKeys() }
                }

                // MARK: - Bulk Action Bar
                if !viewModel.selectedIDs.isEmpty {
                    bulkActionBar
                }

                // MARK: - Main Key List
                List {
                    if filteredKeys.isEmpty {
                        //ContentUnavailableView("ไม่พบข้อมูล License Key", systemImage: "key.slash")

VStack(spacing: 12) {
    Image(systemName: "key.slash")
        .font(.largeTitle)
        .foregroundColor(.secondary)
    Text("ไม่พบข้อมูล License Key")
        .font(.subheadline)
        .foregroundColor(.secondary)
}
.frame(maxWidth: .infinity, minHeight: 200)

                    } else {
                        ForEach(filteredKeys) { key in
                            KeyRowView(
                                key: key,
                                currentTab: viewModel.selectedTab,
                                isSelected: viewModel.selectedIDs.contains(key.id),
                                onSelect: { viewModel.toggleSelection(for: key.id) },
                                onCopy: { copyToClipboard(text: key.tokenCode) },
                                onResetHWID: {
                                    keyToReset = key
                                    showResetSingleAlert = true
                                },
                                onRenew: { selectedKeyForRenew = key },
                                onBanToggle: {
                                    if key.isBanned {
                                        Task { await viewModel.unbanKey(id: key.id) }
                                    } else {
                                        selectedKeyForBan = key
                                    }
                                },
                                onDelete: {
                                    Task { await viewModel.deleteKey(id: key.id) }
                                }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "ค้นหา Key Code หรือ Package...")
                .refreshable {
                    await viewModel.fetchKeys()
                }
            }
            .navigationTitle("License Keys")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.keys.isEmpty {
                        Button(viewModel.selectedIDs.count == viewModel.keys.count ? "Deselect All" : "Select All") {
                            if viewModel.selectedIDs.count == viewModel.keys.count {
                                viewModel.deselectAll()
                            } else {
                                viewModel.selectAll()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showCreateKeySheet = true }) {
                            Label("สร้าง Key ใหม่", systemImage: "plus.circle")
                        }
                        
                        Button(role: .destructive, action: { showResetAllAlert = true }) {
                            Label("Reset HWID ทั้งหมด", systemImage: "arrow.triangle.2.circlepath.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .task {
                await viewModel.fetchKeys()
            }
            .sheet(isPresented: $showCreateKeySheet) {
                CreateKeySheet(viewModel: viewModel)
            }
            .sheet(item: $selectedKeyForBan) { key in
                BanKeySheet(key: key, viewModel: viewModel)
            }
            .sheet(item: $selectedKeyForRenew) { key in
                RenewKeySheet(key: key, viewModel: viewModel)
            }
            .alert("ยืนยัน Reset HWID", isPresented: $showResetSingleAlert, presenting: keyToReset) { key in
                Button("ยกเลิก", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task { await viewModel.resetDevice(id: key.id) }
                }
            } message: { key in
                Text("คุณต้องการล้างรายการอุปกรณ์ที่ผูกไว้กับ Key \(key.tokenCode) หรือไม่?")
            }
            .alert("ล้าง HWID ทั้งหมด!", isPresented: $showResetAllAlert) {
                Button("ยกเลิก", role: .cancel) { }
                Button("Reset ทั้งหมด", role: .destructive) {
                    Task { await viewModel.resetAllDevices() }
                }
            } message: {
                Text("คุณแน่ใจหรือว่าต้องการล้าง HWID ของ Key ทั้งหมดในระบบ?")
            }
        }
    }

    // MARK: - Bulk Action Bar Component
    private var bulkActionBar: some View {
        HStack {
            Text("เลือกอยู่ \(viewModel.selectedIDs.count) รายการ")
                .font(.subheadline)
                .fontWeight(.bold)
            
            Spacer()
            
            Menu("ดำเนินการ") {
                switch viewModel.selectedTab {
                case .active:
                    Button("🔄 Reset HWID รายการที่เลือก") {
                        Task { await viewModel.executeBulkAction("reset_hwid_selected") }
                    }
                    Button("🗑️ ลบรายการที่เลือก", role: .destructive) {
                        Task { await viewModel.executeBulkAction("delete_selected") }
                    }
                case .banned:
                    Button("🔓 ปลดแบนรายการที่เลือก") {
                        Task { await viewModel.executeBulkAction("unban_selected") }
                    }
                    Button("🗑️ ลบรายการที่เลือก", role: .destructive) {
                        Task { await viewModel.executeBulkAction("delete_selected") }
                    }
                case .expired:
                    Button("🗑️ ลบรายการที่เลือก", role: .destructive) {
                        Task { await viewModel.executeBulkAction("delete_selected") }
                    }
                case .deleted:
                    Button("🗑️ ล้างประวัติที่เลือกถาวร", role: .destructive) {
                        Task { await viewModel.executeBulkAction("purge_selected_history") }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
    }

    private func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - Single Row Cell
struct KeyRowView: View {
    let key: LicenseKey
    let currentTab: KeyViewModel.KeyTab
    let isSelected: Bool
    
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onResetHWID: () -> Void
    let onRenew: () -> Void
    let onBanToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Checkbox + Key Code + Copy + Status Badge
            HStack(spacing: 10) {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text(key.tokenCode)
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)

                Spacer()

                KeyStatusBadgeView(key: key, currentTab: currentTab)
            }

            // Sub Info: Package Name & Devices Bound
            HStack {
                if let pname = key.pname {
                    Label(pname, systemImage: "shippingbox.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Label("Device: \(key.deviceUsageString)", systemImage: "iphone.gen3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Expire Date / Ban Reason Info
            if currentTab == .banned {
                if let reason = key.banReason, !reason.isEmpty {
                    Text("สาเหตุ: \(reason)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if let banExpire = key.banExpire {
                    Text("หมดแบน: \(banExpire)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if currentTab == .deleted {
                if let deletedAt = key.deletedAt {
                    Text("วันที่ลบ: \(deletedAt)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text(key.type == .lifetime ? "ประเภท: Lifetime (∞)" : "หมดอายุ: \(key.expireDate ?? "ยังไม่เปิดใช้งาน")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Action Buttons Bar
            if currentTab != .deleted {
                HStack {
                    Button(action: onResetHWID) {
                        Label("Reset HWID", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.orange)

                    Spacer()

                    Button(action: onRenew) {
                        Label("ต่ออายุ", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)

                    Spacer()

                    Button(action: onBanToggle) {
                        Label(key.isBanned ? "ปลดแบน" : "แบน Key",
                              systemImage: key.isBanned ? "checkmark.seal" : "slash.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(key.isBanned ? .green : .red)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if currentTab != .deleted {
                Button(role: .destructive, action: onDelete) {
                    Label("ลบ", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Key Status Badge
struct KeyStatusBadgeView: View {
    let key: LicenseKey
    let currentTab: KeyViewModel.KeyTab

    var body: some View {
        Text(badgeText)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .cornerRadius(6)
    }

    private var badgeText: String {
        if currentTab == .deleted { return "DELETED" }
        if key.isBanned { return "BANNED" }
        if key.isExpired { return "EXPIRED" }
        return "ACTIVE"
    }

    private var badgeColor: Color {
        if currentTab == .deleted { return .gray }
        if key.isBanned { return .red }
        if key.isExpired { return .orange }
        return .green
    }
}

// MARK: - Create Key Sheet (Dummy View หรือนำไปพัฒนาต่อ)
struct CreateKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: KeyViewModel

    @State private var projectId: Int = 1
    @State private var prefixType = "random"
    @State private var customPrefix = ""
    @State private var selectedType: KeyType = .dynamic
    @State private var maxDevices = 1
    @State private var durationNum = 1
    @State private var durationUnit = "DAYS"

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("ตั้งค่า Key")) {
                    Picker("ประเภท Key", selection: $selectedType) {
                        ForEach(KeyType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Stepper("จำนวนเครื่องสูงสุด: \(maxDevices)", value: $maxDevices, in: 1...100)

                    if selectedType != .lifetime {
                        HStack {
                            TextField("ระยะเวลา", value: $durationNum, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                            Picker("หน่วย", selection: $durationUnit) {
                                Text("นาที").tag("MINUTES")
                                Text("ชั่วโมง").tag("HOURS")
                                Text("วัน").tag("DAYS")
                                Text("เดือน").tag("MONTHS")
                            }
                        }
                    }
                }
            }
            .navigationTitle("สร้าง Key ใหม่")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("สร้าง") {
                        Task {
                            let success = await viewModel.createKey(
                                projectId: projectId,
                                prefixType: prefixType,
                                customPrefix: customPrefix,
                                type: selectedType,
                                maxDevices: maxDevices,
                                staticDate: nil,
                                durationNum: durationNum,
                                durationUnit: durationUnit
                            )
                            if success { dismiss() }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Ban Key Sheet
struct BanKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let key: LicenseKey
    @ObservedObject var viewModel: KeyViewModel

    @State private var banType = "perm"
    @State private var hours = 24
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("รายละเอียดการแบน")) {
                    Picker("ประเภทการแบน", selection: $banType) {
                        Text("ถาวร (Permanent)").tag("perm")
                        Text("ชั่วคราว (Temporary)").tag("temp")
                    }

                    if banType == "temp" {
                        Stepper("จำนวนชั่วโมง: \(hours)", value: $hours, in: 1...720)
                    }

                    TextField("ระบุเหตุผลการแบน", text: $reason)
                }
            }
            .navigationTitle("🚫 แบน Key: \(key.tokenCode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ยืนยันแบน") {
                        Task {
                            await viewModel.banKey(
                                id: key.id,
                                banType: banType,
                                hours: banType == "temp" ? hours : nil,
                                reason: reason
                            )
                            dismiss()
                        }
                    }
                    .tint(.red)
                }
            }
        }
    }
}

// MARK: - Renew Key Sheet
struct RenewKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let key: LicenseKey
    @ObservedObject var viewModel: KeyViewModel

    @State private var num = 1
    @State private var unit = "DAYS"

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("เพิ่มเวลาการใช้งาน")) {
                    Stepper("จำนวน: \(num)", value: $num, in: 1...365)
                    Picker("หน่วยเวลา", selection: $unit) {
                        Text("นาที").tag("MINUTES")
                        Text("ชั่วโมง").tag("HOURS")
                        Text("วัน").tag("DAYS")
                        Text("เดือน").tag("MONTHS")
                    }
                }
            }
            .navigationTitle("🔄 ต่ออายุ: \(key.tokenCode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ยืนยัน") {
                        Task {
                            await viewModel.renewKey(id: key.id, num: num, unit: unit)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
