import Foundation
import UIKit
import SwiftUI

@MainActor
class QuickApplyViewModel: ObservableObject {
    let selectedApp: TargetGameApp

    @Published var patchItems: [QuickPatchItem] = []
    @Published var activePatches: [String: Bool] = [:]
    @Published var selectedItems: Set<String> = []
    @Published var selectedCategory: String = SecretKeys.categoryAll
    @Published var isMultiSelectMode = false

    @Published var isLoadingCatalog = false
    @Published var processingItemID: String?
    @Published var isProcessingBatch = false
    @Published var isRestoringAll = false

    private var catalogURL: URL {
        return URL(string: SecretKeys.catalogURL)!
    }

    init(selectedApp: TargetGameApp) {
        self.selectedApp = selectedApp
    }

    // MARK: - Computed Properties
    var filteredGamePatches: [QuickPatchItem] {
        patchItems.filter { item in
            guard let bId = item.bundleID, !bId.isEmpty else { return true }
            return bId.lowercased() == selectedApp.bundleID.lowercased()
        }
    }

    var availableCategories: [String] {
        var categories = [SecretKeys.categoryAll]
        let rawCategories = filteredGamePatches.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for cat in rawCategories where !cat.isEmpty {
            if !categories.contains(where: { $0.lowercased() == cat.lowercased() }) {
                categories.append(cat)
            }
        }
        return categories
    }

    var displayedPatches: [QuickPatchItem] {
        if selectedCategory == SecretKeys.categoryAll {
            return filteredGamePatches
        }
        return filteredGamePatches.filter {
            ($0.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == selectedCategory.lowercased()
        }
    }

    var activeDisplayedPatchesCount: Int {
        displayedPatches.filter { $0.active ?? true }.count
    }

    var hasActivePatches: Bool {
        activePatches.values.contains(true)
    }

    var availableItems: [QuickPatchItem] {
        filteredGamePatches.filter { $0.active ?? true }
    }

    func countForCategory(_ category: String) -> Int? {
        if category == SecretKeys.categoryAll {
            return filteredGamePatches.count
        }
        return filteredGamePatches.filter {
            ($0.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == category.lowercased()
        }.count
    }

    // MARK: - User Actions
    func toggleSelection(for item: QuickPatchItem) {
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

    func toggleSelectAll() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isMultiSelectMode.toggle()
            if !isMultiSelectMode {
                selectedItems.removeAll()
            }
        }
    }

    func openGame() {
        let success = AppLauncher.launchApp(bundleID: selectedApp.bundleID)
        if !success {
            showErrorNotification(message: "\(SecretKeys.msgLaunchAppFailedPrefix)\(selectedApp.name)\(SecretKeys.msgLaunchAppFailedSuffix)")
        }
    }

    // MARK: - Notifications
    func showSuccessNotification(message: String) {
        let icon = UIImage(systemName: SecretKeys.iconCheckmarkCircle)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        FTNotificationIndicator.setNotificationIndicatorStyle(.dark)
        FTNotificationIndicator.showNotification(
            with: icon,
            title: SecretKeys.titleSuccess,
            message: message
        )
    }

    func showErrorNotification(message: String) {
        let icon = UIImage(systemName: SecretKeys.iconWarningTriangle)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        FTNotificationIndicator.setNotificationIndicatorStyle(.dark)
        FTNotificationIndicator.showNotification(
            with: icon,
            title: SecretKeys.titleFailed,
            message: message
        )
    }

    // MARK: - Network & Storage Logic
    private func localPatchURL(for id: String) -> URL? {
        guard let appSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let targetDirectory = appSupportURL.appendingPathComponent(SecretKeys.c4Directory, isDirectory: true)
        return targetDirectory.appendingPathComponent("\(id)\(SecretKeys.c4Extension)")
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
        request.setValue(SecretKeys.userAgentValue, forHTTPHeaderField: SecretKeys.userAgentHeader)

        // 🟢 ใช้ URLSession.pinned ที่ผูก SSL Pinning Delegate ไว้แล้ว
        let (tempURL, response) = try await URLSession.pinned.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PatchPackageError.invalidProject
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }

    func fetchCatalog(force: Bool = false) async {
        if !patchItems.isEmpty && !force { return }

        isLoadingCatalog = true 
        HUDHelper.show(message: "")
        
        let startTime = Date()

        do {
            var request = URLRequest(
                url: catalogURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.httpMethod = "GET"
            request.setValue(SecretKeys.userAgentValue, forHTTPHeaderField: SecretKeys.userAgentHeader)

            // 🟢 ใช้ URLSession.pinned ที่ผูก SSL Pinning Delegate ไว้แล้ว
            let (data, response) = try await URLSession.pinned.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let items = try JSONDecoder().decode([QuickPatchItem].self, from: data)

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
        } catch {
            print("Fetch catalog failed: \(error)")
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        let minDuration: TimeInterval = 1.0
        if elapsedTime < minDuration {
            let remainingTime = UInt64((minDuration - elapsedTime) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remainingTime)
        }

        self.isLoadingCatalog = false
        HUDHelper.hide()
    }

    private nonisolated func translatePatchError(_ error: PatchPackageError) -> String {
        switch error.localizationKey {
        case SecretKeys.errKeyInvalidProject:
            return SecretKeys.errMsgInvalidProject
        case SecretKeys.errKeyAppUnavailable:
            return "\(SecretKeys.errMsgAppUnavailablePrefix)\(selectedApp.bundleID)\(SecretKeys.errMsgAppUnavailableSuffix)"
        case SecretKeys.errKeyApply:
            return SecretKeys.errMsgApply
        case SecretKeys.errKeyDuplicateTarget:
            return SecretKeys.errMsgDuplicateTarget
        case SecretKeys.errKeyInvalidBundle:
            return SecretKeys.errMsgInvalidBundle
        case SecretKeys.errKeyPasswordOrCorrupt:
            return SecretKeys.errMsgPasswordOrCorrupt
        case SecretKeys.errKeyRestore:
            return SecretKeys.errMsgRestore
        case SecretKeys.errKeySizeLimit:
            return SecretKeys.errMsgSizeLimit
        default:
            return error.localizationKey
        }
    }

    func handleToggleChange(item: QuickPatchItem, enable: Bool) {
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
                        self.showSuccessNotification(message: SecretKeys.msgPatchAppliedSuccess)
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
                        self.showSuccessNotification(message: SecretKeys.msgPatchRestoredSuccess)
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
                    let message = enable ? SecretKeys.msgPatchApplyFailed : SecretKeys.msgPatchRestoreFailed
                    self.showErrorNotification(message: message)
                }
            }
        }
    }

    func applyBatchPatches() {
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
                    self.showSuccessNotification(message: "\(SecretKeys.msgBatchAppliedSuccessPrefix)\(finalSuccessCount)\(SecretKeys.msgBatchAppliedSuccessSuffix)")
                } else {
                    self.showErrorNotification(message: SecretKeys.msgBatchAppliedFailed)
                }
            }
        }
    }

    func restoreAllPatches() {
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
                    self.showSuccessNotification(message: SecretKeys.msgPatchRestoredSuccess)
                } else {
                    self.showSuccessNotification(message: SecretKeys.msgRestoreAllResetSuccess)
                }
            }
        }
    }
}
