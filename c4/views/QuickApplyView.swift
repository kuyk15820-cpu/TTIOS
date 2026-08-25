import SwiftUI
import UIKit

// MARK: - Relative Date Helpers

extension String {
    /// แปลงข้อความวันเวลา (ISO 8601) เป็นเวลาเปรียบเทียบ เช่น "เมื่อสักครู่", "5 นาทีที่แล้ว"
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
    let updatedAt: String? // เวลา ISO 8601 จาก Server
    let downloadUrl: String
    let active: Bool?
    let category: String? // อ่านค่า category จาก Server (เช่น "Aim", "Hologram")
    let bundleID: String? // รองรับการกรองแยกรายเกม เช่น "com.dts.freefireth"
    
    // เช็คว่าเป็นหมวดหมู่ Aim หรือไม่
    var isAimCategory: Bool {
        if let cat = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !cat.isEmpty {
            return cat == "aim"
        }
        let text = "\(id) \(title)".lowercased()
        return text.contains("aim") || text.contains("ลาก") || text.contains("หัว")
    }
}

// MARK: - Tab Button Component (From AnalysisTabView)

struct TabButton: View {
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

// MARK: - QuickApplyView

struct QuickApplyView: View {
    let selectedApp: TargetGameApp

    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    private let catalogURL = URL(string: "https://f1x3r.org/patches/catalog.json")!

    @State private var patchItems: [QuickPatchItem] = []
    @State private var activePatches: [String: Bool] = [:]
    @State private var selectedItems: Set<String> = []
    
    // Index ของหมวดหมู่ที่เลือก (ใช้ Int เพื่อผูกกับ TabView Paging)
    @State private var selectedCategoryIndex: Int = 0
    // State สำหรับควบคุมโหมดเลือกหลายรายการ
    @State private var isMultiSelectMode: Bool = false
    
    @State private var isLoadingCatalog = false
    @State private var processingItemID: String?
    @State private var isProcessingBatch = false
    @State private var isRestoringAll = false
    @State private var showSettings = false
    @State private var showLogs = false

    // กรอง Patch ที่ตรงกับ Bundle ID ของเกมปัจจุบันเท่านั้น
    private var filteredGamePatches: [QuickPatchItem] {
        patchItems.filter { item in
            guard let bId = item.bundleID, !bId.isEmpty else { return true }
            return bId.lowercased() == selectedApp.bundleID.lowercased()
        }
    }

    // รายการ Patch ทั้งหมดที่พร้อมสกัด หมวดหมู่
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

    // รายการ Patch ตามหมวดหมู่ที่ระบุ
    private func patches(for category: String) -> [QuickPatchItem] {
        if category == "ทั้งหมด" {
            return filteredGamePatches
        }
        return filteredGamePatches.filter {
            ($0.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == category.lowercased()
        }
    }

    // เช็คว่ามี Patch ไหนเปิดใช้งานอยู่หรือไม่
    private var hasActivePatches: Bool {
        activePatches.values.contains(true)
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
            if !isLoadingCatalog && availableCategories.count > 1 {
                categoryFilterBar
            }

            if isLoadingCatalog {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                // TabView สไตล์ Paging สำหรับปัดซ้าย-ขวา
                TabView(selection: $selectedCategoryIndex) {
                    ForEach(Array(availableCategories.enumerated()), id: \.offset) { index, category in
                        List {
                            patchCatalogSection(for: patches(for: category))
                        }
                        .listStyle(.plain)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            if !filteredGamePatches.isEmpty && !isLoadingCatalog {
                bottomActionButtons
            }
        }
        .navigationTitle(selectedApp.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(AppTheme.accent)
        .toolbar {
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

    // MARK: - Category Filter Bar (Auto-scroll ตามการปัดหน้า)

    private var categoryFilterBar: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(availableCategories.enumerated()), id: \.offset) { index, category in
                            TabButton(
                                title: category,
                                isSelected: selectedCategoryIndex == index,
                                count: countForCategory(category)
                            ) {
                                withAnimation {
                                    selectedCategoryIndex = index
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedCategoryIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .background(Color(.systemBackground))

            Divider()
        }
    }

    // MARK: - Patch Catalog Section (แคปซูล เลือกหลายรายการ + ไม่มี Header Text)

    @ViewBuilder
    private func patchCatalogSection(for items: [QuickPatchItem]) -> some View {
        Section {
            ForEach(items) { item in
                patchRow(for: item)
            }
        } header: {
            HStack {
                Spacer()
                
                // ปุ่มแคปซูล "เลือกหลายรายการ"
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedItems.removeAll()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "plus.circle")
                            .font(.caption.bold())
                        Text(isMultiSelectMode ? "ยกเลิกเลือกหลายรายการ" : "เลือกหลายรายการ")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isMultiSelectMode ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.12))
                    .foregroundStyle(isMultiSelectMode ? AppTheme.accent : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func patchRow(for item: QuickPatchItem) -> some View {
        let isApplied = activePatches[item.id] ?? false
        let isSelected = selectedItems.contains(item.id)
        let isServerActive = item.active ?? true

        HStack(alignment: .center, spacing: 8) {
            Button {
                if isServerActive && processingItemID == nil && !isRestoringAll && !isProcessingBatch {
                    if isMultiSelectMode {
                        toggleSelection(for: item)
                    } else {
                        handleToggleChange(item: item, enable: !isApplied)
                    }
                }
            } label: {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isServerActive || processingItemID != nil || isRestoringAll || isProcessingBatch)
            .opacity(isServerActive ? 1.0 : 0.75)

            Spacer(minLength: 4)

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
                    .opacity(1.0)
            }

            // แสดง Icon ตามสถานะโหมด Multi-Select และ การติดตั้ง
            if isMultiSelectMode {
                // อยู่ในโหมดเลือกหลายรายการ: แสดงวงกลมสำหรับให้ User ติ๊กเลือกเอง
                Button {
                    if isServerActive && processingItemID == nil && !isRestoringAll && !isProcessingBatch {
                        toggleSelection(for: item)
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                        } else {
                            Image(systemName: "circle")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 28, height: 28, alignment: .center)
                }
                .buttonStyle(.plain)
                .disabled(!isServerActive || processingItemID != nil || isRestoringAll || isProcessingBatch)
            } else if isApplied {
                // ไม่ได้อยู่ในโหมดเลือกหลายรายการ: แสดงเฉพาะเครื่องหมาย Checkmark เมื่อใช้งานอยู่
                Button {
                    if processingItemID == nil && !isRestoringAll && !isProcessingBatch {
                        handleToggleChange(item: item, enable: false)
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28, alignment: .center)
                }
                .buttonStyle(.plain)
                .disabled(processingItemID != nil || isRestoringAll || isProcessingBatch)
            }
        }
        .padding(.vertical, 4)
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
    }

    // MARK: - Selection Handlers

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

    // MARK: - Notification Helpers (FTNotificationIndicator)

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

    // MARK: - File Management & Logic

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

    // MARK: - Error Message Translator

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
                    // ปลดล็อกหมวดหมู่ Aim อื่นถ้ามี และเคลียร์ Receipt เก่าออกแบบเงียบๆ
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

                    // สั่งถอนการติดตั้ง Patch เดิมของตัวเองก่อน หากมีไฟล์เก่าค้างอยู่
                    if FileManager.default.fileExists(atPath: applyURL.path),
                       let existingData = try? Data(contentsOf: applyURL),
                       let existingDecoded = try? PatchPackageCodec.decode(existingData, password: nil),
                       let existingReceipt = DevicePatchService.latestReceipt(projectID: existingDecoded.project.id) {
                        try? DevicePatchService.restore(receipt: existingReceipt)
                    }

                    // ดาวน์โหลดและทำการ Apply Patch ใหม่
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
                    // กรณีสั่งถอน Patch (Restore)
                    if FileManager.default.fileExists(atPath: applyURL.path) {
                        if let packageData = try? Data(contentsOf: applyURL),
                           let decodedPackage = try? PatchPackageCodec.decode(packageData, password: nil),
                           let receipt = DevicePatchService.latestReceipt(projectID: decodedPackage.project.id) {
                            // พยายามย้อนคืนไฟล์ตาม Receipt
                            try? DevicePatchService.restore(receipt: receipt)
                        }
                        // ลบไฟล์ท้องถิ่นออกเพื่อล้างสถานะ
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
                self.isMultiSelectMode = false
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
                self.isMultiSelectMode = false
                if finalCount > 0 {
                    self.showSuccessNotification(message: "คืนค่า Patch ต้นฉบับเรียบร้อยแล้ว")
                } else {
                    self.showSuccessNotification(message: "รีเซ็ตสถานะคืนค่าเดิมทั้งหมดเรียบร้อยแล้ว")
                }
            }
        }
    }
}
