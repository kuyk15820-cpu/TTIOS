import SwiftUI
import UIKit

// MARK: - Native List Row Button Style ( Highlight Effect ตอนกด )

struct NativeListRowButtonStyle: ButtonStyle {
    let isDisabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed && !isDisabled
                    ? Color(.systemFill)
                    : Color(.systemBackground)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Relative Date Helpers

extension String {
    var toRelativeTimeText: String {
        guard let date = try? Date(self, strategy: .iso8601) else {
            return self
        }
        let safeDate = min(date, Date())
        return safeDate.formatted(.relative(presentation: .named).locale(Locale(identifier: "th_TH")))
    }
}

// MARK: - Models

struct QuickPatchItem: Identifiable, Codable {
    let id: String
    let title: String
    let updatedAt: String?
    let downloadUrl: String
    let active: Bool?
    let category: String?
    let bundleID: String?
    
    var isAimCategory: Bool {
        if let cat = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !cat.isEmpty {
            return cat == "aim"
        }
        let text = "\(id) \(title)".lowercased()
        return text.contains("aim") || text.contains("ลาก") || text.contains("หัว")
    }
}

// MARK: - Filter Bar Component

struct CategoryTabBar: View {
    let categories: [String]
    @Binding var selectedCategory: String
    let countProvider: (String) -> Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(categories, id: \.self) { category in
                        CategoryTabButton(
                            title: category,
                            isSelected: selectedCategory == category,
                            count: countProvider(category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))

            Divider()
        }
    }
}

struct CategoryTabButton: View {
    let title: String
    let isSelected: Bool
    var count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count = count {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QuickApplyView (UI Native List + ScrollView Engine)

struct QuickApplyView: View {
    let selectedApp: TargetGameApp

    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    private let catalogURL = URL(string: "https://f1x3r.org/patches/catalog.json")!

    @State private var patchItems: [QuickPatchItem] = []
    @State private var activePatches: [String: Bool] = [:]
    @State private var selectedItems: Set<String> = []
    @State private var selectedCategory: String = "ทั้งหมด"
    
    // โหมดแก้ไข (Multi-selection Mode)
    @State private var isEditing = false

    @State private var isLoadingCatalog = false
    @State private var processingItemID: String?
    @State private var isProcessingBatch = false
    @State private var isRestoringAll = false
    @State private var showSettings = false
    @State private var showLogs = false

    private var filteredGamePatches: [QuickPatchItem] {
        patchItems.filter { item in
            guard let bId = item.bundleID, !bId.isEmpty else { return true }
            return bId.lowercased() == selectedApp.bundleID.lowercased()
        }
    }

    private var availableCategories: [String] {
        var categories = ["ทั้งหมด"]
        let rawCategories = filteredGamePatches.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for cat in rawCategories where !cat.isEmpty {
            if !categories.contains(where: { $0.lowercased() == cat.lowercased() }) {
                categories.append(cat)
            }
        }
        return categories
    }

    private var displayedPatches: [QuickPatchItem] {
        if selectedCategory == "ทั้งหมด" {
            return filteredGamePatches
        }
        return filteredGamePatches.filter {
            ($0.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == selectedCategory.lowercased()
        }
    }

    private var activeDisplayedPatchesCount: Int {
        displayedPatches.filter { $0.active ?? true }.count
    }

    private var hasActivePatches: Bool {
        activePatches.values.contains(true)
    }

    private var availableItems: [QuickPatchItem] {
        filteredGamePatches.filter { $0.active ?? true }
    }

    private func countForCategory(_ category: String) -> Int? {
        if category == "ทั้งหมด" {
            return filteredGamePatches.count
        }
        return filteredGamePatches.filter {
            ($0.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == category.lowercased()
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Tab Bar
            if !isLoadingCatalog && availableCategories.count > 1 {
                CategoryTabBar(
                    categories: availableCategories,
                    selectedCategory: $selectedCategory,
                    countProvider: { cat in countForCategory(cat) }
                )
            }

            // Main Content Area
            if isLoadingCatalog {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if displayedPatches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("ไม่พบรายการ Patch")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Section Header สไตล์ Native List
                        HStack {
                            Text("รายการ Patch ที่พร้อมใช้งาน (\(activeDisplayedPatchesCount))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // ปุ่มเลือกหลายรายการทรงแคปซูล แสดงเมื่อกด "แก้ไข"
                            if isEditing {
                                Button {
                                    toggleSelectAll()
                                } label: {
                                    let allSelected = isAllSmartSelected()
                                    HStack(spacing: 4) {
                                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text("เลือกหลายรายการ")
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(allSelected ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.12))
                                    .foregroundColor(allSelected ? AppTheme.accent : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Color(.systemGroupedBackground))

                        Divider()

                        // Patch List Rows (สร้าง UI ถอดแบบ Plain List 100%)
                        ForEach(displayedPatches) { item in
                            patchRow(for: item)
                            Divider()
                                .padding(.leading, 16) // ย่อ Divider ตามมาตรฐาน iOS List
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
            
            // Bottom Controls
            if !filteredGamePatches.isEmpty && !isLoadingCatalog {
                bottomActionButtons
            }
        }
        .navigationTitle(selectedApp.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(AppTheme.accent)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEditing.toggle()
                        if !isEditing {
                            selectedItems.removeAll()
                        }
                    }
                } label: {
                    Text(isEditing ? "เสร็จสิ้น" : "แก้ไข")
                        .font(.body.weight(isEditing ? .bold : .regular))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showLogs = true } label: {
                    Image(systemName: "apple.terminal")
                }
                .accessibilityLabel("เปิดบันทึกประวัติ (Logs)")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("เปิดการตั้งค่า")
            }
        }
        .task {
            await fetchCatalog()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
    }

    // MARK: - Patch Row Component ( Highlight ทึบเมื่อคลิก + ทึบพิเศษเมื่อปิดปรับปรุง )

    @ViewBuilder
    private func patchRow(for item: QuickPatchItem) -> some View {
        let isApplied = activePatches[item.id] ?? false
        let isSelected = selectedItems.contains(item.id)
        let isServerActive = item.active ?? true
        let isDisabled = processingItemID != nil || isRestoringAll || isProcessingBatch

        Button {
            guard !isDisabled else { return }
            
            if !isServerActive {
                if isApplied {
                    handleToggleChange(item: item, enable: false)
                }
                return
            }

            if isEditing {
                toggleSelection(for: item)
            } else {
                handleToggleChange(item: item, enable: !isApplied)
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                // ไอคอนเลือกหลายรายการ (แสดงฝั่งซ้ายเมื่อเปิดโหมดแก้ไข)
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.4))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // เนื้อหาหลักของ Row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        
                        if let category = item.category {
                            Text("[\(category)]")
                                .font(.caption.bold())
                                .foregroundStyle(item.isAimCategory ? .orange : .blue)
                        }
                    }

                    if let updatedAt = item.updatedAt, !updatedAt.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("อัปเดตเมื่อ: \(updatedAt.toRelativeTimeText)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                // ป้ายบอกสถานะปิดปรับปรุง
                if !isServerActive {
                    Text("ปิดปรับปรุง")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(.red)
                        .background(Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.red, lineWidth: 1.0)
                        )
                        .clipShape(Capsule())
                }

                // แสดงไอคอนเปิดใช้งานฝั่งขวา (เฉพาะเมื่อเปิดใช้งานเท่านั้น)
                if isApplied {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            // ปรับระดับความทึบลงเหลือ 0.35 + ปลดสีสันออกเมื่อปิดปรับปรุง
            .opacity(isServerActive ? 1.0 : 0.35)
            .grayscale(isServerActive ? 0.0 : 1.0)
        }
        .buttonStyle(NativeListRowButtonStyle(isDisabled: isDisabled || (!isServerActive && !isApplied)))
        .disabled(isDisabled || (!isServerActive && !isApplied))
    }

    // MARK: - Bottom Action Buttons

    private var bottomActionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    restoreAllPatches()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.headline)
                        
                        Text("คืนค่าเดิมทั้งหมด")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }
                .disabled(!hasActivePatches || processingItemID != nil || isRestoringAll || isProcessingBatch || isLoadingCatalog)
                .opacity(hasActivePatches ? 1.0 : 0.4)

                Button {
                    openGame()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller")
                            .font(.headline)
                        Text("เปิดเกม")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }
                .disabled(processingItemID != nil || isRestoringAll || isProcessingBatch || isLoadingCatalog)
            }

            if !selectedItems.isEmpty {
                Button {
                    applyBatchPatches()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.headline)
                        Text("Patch หลายรายการ (\(selectedItems.count))")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }
                .disabled(processingItemID != nil || isRestoringAll || isProcessingBatch || isLoadingCatalog)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedItems.isEmpty)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Logic Handlers

    private func toggleSelection(for item: QuickPatchItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            if item.isAimCategory {
                let currentAimIDs = filteredGamePatches.filter { $0.isAimCategory }.map { $0.id }
                selectedItems.subtract(currentAimIDs)
            }
            selectedItems.insert(item.id)
        }
    }

    private func isAllSmartSelected() -> Bool {
        guard !availableItems.isEmpty else { return false }
        
        let firstAim = availableItems.first(where: { $0.isAimCategory })
        let otherItems = availableItems.filter { !$0.isAimCategory }
        
        var expectedIDs = Set(otherItems.map { $0.id })
        if let aim = firstAim {
            expectedIDs.insert(aim.id)
        }
        
        return selectedItems == expectedIDs
    }

    private func toggleSelectAll() {
        if isAllSmartSelected() {
            selectedItems.removeAll()
        } else {
            var newSelection = Set<String>()
            
            if let firstAim = availableItems.first(where: { $0.isAimCategory }) {
                newSelection.insert(firstAim.id)
            }
            
            let nonAimItems = availableItems.filter { !$0.isAimCategory }
            for item in nonAimItems {
                newSelection.insert(item.id)
            }
            
            selectedItems = newSelection
        }
    }

    @MainActor
    private func showSuccessNotification(message: String) {
        let icon = UIImage(systemName: "checkmark.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        FTNotificationIndicator.setNotificationIndicatorStyle(.dark)
        FTNotificationIndicator.showNotification(
            with: icon,
            title: "สำเร็จ",
            message: message
        )
    }

    @MainActor
    private func showErrorNotification(message: String) {
        let icon = UIImage(systemName: "exclamationmark.triangle")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        FTNotificationIndicator.setNotificationIndicatorStyle(.dark)
        FTNotificationIndicator.showNotification(
            with: icon,
            title: "ล้มเหลว",
            message: message
        )
    }

    private func openGame() {
        let success = AppLauncher.launchApp(bundleID: selectedApp.bundleID)
        if !success {
            showErrorNotification(message: "ไม่สามารถเปิดแอปพลิเคชัน \(selectedApp.name) ได้")
        }
    }

    private func localPatchURL(for id: String) -> URL? {
        guard let appSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let targetDirectory = appSupportURL.appendingPathComponent(".c4", isDirectory: true)
        return targetDirectory.appendingPathComponent("\(id).c4")
    }

    private func downloadFile(from urlString: String, to destinationURL: URL) async throws {
        guard let remoteURL = URL(string: urlString) else {
            throw PatchPackageError.invalidProject
        }

        let fileManager = FileManager.default
        let targetDirectory = destinationURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }

        var request = URLRequest(
            url: remoteURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PatchPackageError.invalidProject
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }

    private func fetchCatalog(force: Bool = false) async {
        if !patchItems.isEmpty && !force { return }

        await MainActor.run { 
            isLoadingCatalog = true 
            HUDHelper.show(message: "")
        }
        let startTime = Date()

        do {
            var request = URLRequest(
                url: catalogURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let items = try JSONDecoder().decode([QuickPatchItem].self, from: data)

                await MainActor.run {
                    self.patchItems = items

                    for item in items {
                        if let localURL = self.localPatchURL(for: item.id),
                           FileManager.default.fileExists(atPath: localURL.path),
                           let packageData = try? Data(contentsOf: localURL),
                           let decoded = try? PatchPackageCodec.decode(packageData, password: nil) {

                            let hasReceipt = DevicePatchService.latestReceipt(projectID: decoded.project.id) != nil
                            self.activePatches[item.id] = hasReceipt
                        } else {
                            self.activePatches[item.id] = false
                        }
                    }
                }
            }
        } catch {
            print("Fetch catalog failed: \(error)")
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        let minDuration: TimeInterval = 1.0
        if elapsedTime < minDuration {
            let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remainingTime)
        }

        await MainActor.run {
            self.isLoadingCatalog = false
            HUDHelper.hide()
        }
    }

    private nonisolated func translatePatchError(_ error: PatchPackageError) -> String {
        switch error.localizationKey {
        case "patch.error.invalid_project":
            return "โปรดตรวจสอบชื่อโปรเจกต์, Bundle เป้าหมาย และเนื้อหาใน Workspace"
        case "patch.error.app_unavailable":
            return "ไม่พบหรือไม่สามารถเปิดแอป Bundle \(selectedApp.bundleID) ได้"
        case "patch.error.apply":
            return "ไม่สามารถใช้งาน Patch ได้ ระบบได้ทำการย้อนคืนการเขียนไฟล์ก่อนหน้าทั้งหมดแล้ว"
        case "patch.error.duplicate_target":
            return "มีเงื่อนไข (Rules) ซ้ำซ้อนที่ชี้ไปที่ไฟล์แอปเดียวกัน"
        case "patch.error.invalid_bundle":
            return "โปรดระบุ App Bundle Identifier ที่ถูกต้อง ไม่ใช่ Container UUID"
        case "patch.error.password_or_corrupt":
            return "รหัสผ่านไม่ถูกต้อง หรือไฟล์ Package ถูกดัดแปลง/เสียหาย"
        case "patch.error.restore":
            return "ไม่สามารถคืนค่าไฟล์ต้นฉบับได้อย่างปลอดภัย ไม่มีเป้าหมายที่ไม่ได้รับการยืนยันถูกเขียนทับ"
        case "patch.error.size_limit":
            return "ไฟล์ Package หรือไฟล์ที่นำมาแทนที่ มีขนาดเกินขีดจำกัดที่รองรับ"
        default:
            return error.localizationKey
        }
    }

    private func handleToggleChange(item: QuickPatchItem, enable: Bool) {
        processingItemID = item.id

        Task.detached(priority: .userInitiated) {
            do {
                guard let applyURL = await self.localPatchURL(for: item.id) else {
                    throw PatchPackageError.invalidProject
                }

                if enable {
                    if item.isAimCategory {
                        let activeAimItems = await self.filteredGamePatches.filter { $0.isAimCategory && $0.id != item.id }
                        for aimItem in activeAimItems {
                            await MainActor.run {
                                self.activePatches[aimItem.id] = false
                            }
                            if let aimURL = await self.localPatchURL(for: aimItem.id),
                               FileManager.default.fileExists(atPath: aimURL.path),
                               let packageData = try? Data(contentsOf: aimURL),
                               let decodedPackage = try? PatchPackageCodec.decode(packageData, password: nil) {
                                
                                if let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) {
                                    try? DevicePatchService.restore(receipt: receipt)
                                }
                                try? FileManager.default.removeItem(at: aimURL)
                            }
                        }
                    }

                    if FileManager.default.fileExists(atPath: applyURL.path),
                       let existingData = try? Data(contentsOf: applyURL),
                       let existingDecoded = try? PatchPackageCodec.decode(existingData, password: nil),
                       let existingReceipt = DevicePatchService.latestReceipt(projectID: existingDecoded.project.id) {
                        try? DevicePatchService.restore(receipt: existingReceipt)
                    }

                    try await self.downloadFile(from: item.downloadUrl, to: applyURL)

                    let packageData = try Data(contentsOf: applyURL)
                    let decodedPackage = try PatchPackageCodec.decode(packageData, password: nil)

                    _ = try DevicePatchService.apply(project: decodedPackage.project)

                    await MainActor.run {
                        self.activePatches[item.id] = true
                        self.processingItemID = nil
                        self.showSuccessNotification(message: "ติดตั้ง Patch เรียบร้อยแล้ว")
                    }

                } else {
                    if FileManager.default.fileExists(atPath: applyURL.path) {
                        if let packageData = try? Data(contentsOf: applyURL),
                           let decodedPackage = try? PatchPackageCodec.decode(packageData, password: nil),
                           let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) {
                            try? DevicePatchService.restore(receipt: receipt)
                        }
                        try? FileManager.default.removeItem(at: applyURL)
                    }

                    await MainActor.run {
                        self.activePatches[item.id] = false
                        self.processingItemID = nil
                        self.showSuccessNotification(message: "คืนค่า Patch ต้นฉบับเรียบร้อยแล้ว")
                    }
                }
            } catch let error as PatchPackageError {
                let message = self.translatePatchError(error)
                await MainActor.run {
                    self.processingItemID = nil
                    self.showErrorNotification(message: message)
                }
            } catch {
                await MainActor.run {
                    self.processingItemID = nil
                    let message = enable ? "ไม่สามารถใช้งาน Patch ได้ ระบบได้ทำการยกเลิกการเขียนไฟล์ก่อนหน้าทั้งหมดแล้ว" : "ไม่สามารถคืนค่าไฟล์ต้นฉบับได้"
                    self.showErrorNotification(message: message)
                }
            }
        }
    }

    private func applyBatchPatches() {
        isProcessingBatch = true

        Task.detached(priority: .userInitiated) {
            let selectedIDs = await self.selectedItems
            let itemsToApply = await self.filteredGamePatches.filter { selectedIDs.contains($0.id) }
            var successCount = 0

            for item in itemsToApply {
                do {
                    guard let applyURL = await self.localPatchURL(for: item.id) else { continue }

                    if item.isAimCategory {
                        let activeAimItems = await self.filteredGamePatches.filter { $0.isAimCategory && $0.id != item.id }
                        for aimItem in activeAimItems {
                            await MainActor.run {
                                self.activePatches[aimItem.id] = false
                            }
                            if let aimURL = await self.localPatchURL(for: aimItem.id),
                               FileManager.default.fileExists(atPath: aimURL.path),
                               let packageData = try? Data(contentsOf: aimURL),
                               let decodedPackage = try? PatchPackageCodec.decode(packageData, password: nil) {
                                
                                if let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) {
                                    try? DevicePatchService.restore(receipt: receipt)
                                }
                                try? FileManager.default.removeItem(at: aimURL)
                            }
                        }
                    }

                    if FileManager.default.fileExists(atPath: applyURL.path),
                       let existingData = try? Data(contentsOf: applyURL),
                       let existingDecoded = try? PatchPackageCodec.decode(existingData, password: nil),
                       let existingReceipt = DevicePatchService.latestReceipt(projectID: existingDecoded.project.id) {
                        try? DevicePatchService.restore(receipt: existingReceipt)
                    }

                    try await self.downloadFile(from: item.downloadUrl, to: applyURL)

                    let packageData = try Data(contentsOf: applyURL)
                    let decodedPackage = try PatchPackageCodec.decode(packageData, password: nil)

                    _ = try DevicePatchService.apply(project: decodedPackage.project)

                    successCount += 1
                    await MainActor.run {
                        self.activePatches[item.id] = true
                    }
                } catch {
                    print("Failed batch patch item \(item.id): \(error)")
                }
            }

            let finalSuccessCount = successCount
            await MainActor.run {
                self.isProcessingBatch = false
                self.selectedItems.removeAll()
                self.isEditing = false
                if finalSuccessCount > 0 {
                    self.showSuccessNotification(message: "ติดตั้ง Patch (\(finalSuccessCount) รายการ) เรียบร้อยแล้ว")
                } else {
                    self.showErrorNotification(message: "ไม่สามารถติดตั้ง Patch ที่เลือกได้")
                }
            }
        }
    }

    private func restoreAllPatches() {
        isRestoringAll = true

        Task.detached(priority: .userInitiated) {
            var count = 0
            let currentItems = await self.filteredGamePatches

            for item in currentItems {
                guard let applyURL = await self.localPatchURL(for: item.id) else { continue }

                if FileManager.default.fileExists(atPath: applyURL.path) {
                    if let packageData = try? Data(contentsOf: applyURL),
                       let decodedPackage = try? PatchPackageCodec.decode(packageData, password: nil),
                       let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) {
                        if (try? DevicePatchService.restore(receipt: receipt)) != nil {
                            count += 1
                        }
                    }
                    try? FileManager.default.removeItem(at: applyURL)
                }

                await MainActor.run {
                    self.activePatches[item.id] = false
                }
            }

            let finalCount = count
            await MainActor.run {
                self.isRestoringAll = false
                self.selectedItems.removeAll()
                self.isEditing = false
                if finalCount > 0 {
                    self.showSuccessNotification(message: "คืนค่า Patch ต้นฉบับเรียบร้อยแล้ว")
                } else {
                    self.showSuccessNotification(message: "รีเซ็ตสถานะคืนค่าเดิมทั้งหมดเรียบร้อยแล้ว")
                }
            }
        }
    }
}
