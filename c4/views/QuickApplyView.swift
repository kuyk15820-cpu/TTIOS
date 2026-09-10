import SwiftUI
import UIKit
import Network

// MARK: - Filter Bar Components

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

// MARK: - Native List Content Configuration Wrapper
// ดึงสไตล์ Layout, Font, Spacing Standard ของ iOS Native (UICollectionViewListCell) มาใช้ใน SwiftUI

struct NativeListRowContent: UIViewRepresentable {
    let title: String
    let detail: String?
    let isServerActive: Bool

    func makeUIView(context: Context) -> UIListContentView {
        var config = UIListContentConfiguration.subtitleCell()
        config.image = UIImage(systemName: "doc.fill")
        config.imageProperties.tintColor = .secondaryLabel
        return UIListContentView(configuration: config)
    }

    func updateUIView(_ uiView: UIListContentView, context: Context) {
        var config = UIListContentConfiguration.subtitleCell()
        
        // ข้อความหลัก (Title)
        config.text = title
        config.textProperties.color = isServerActive ? .label : .secondaryLabel
        
        // ข้อความรอง (Subtitle)
        if let detail = detail, !detail.isEmpty {
            config.secondaryText = detail
            config.secondaryTextProperties.color = .secondaryLabel
        } else {
            config.secondaryText = nil
        }
        
        // ไอคอน Standard ด้านซ้าย
        config.image = UIImage(systemName: "doc.fill")
        config.imageProperties.tintColor = isServerActive ? .secondaryLabel : .tertiaryLabel
        
        uiView.configuration = config
    }
}

// MARK: - QuickApplyView

struct QuickApplyView: View {
    @StateObject private var viewModel: QuickApplyViewModel
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    @State private var networkMonitor: NWPathMonitor?

    init(selectedApp: TargetGameApp) {
        _viewModel = StateObject(wrappedValue: QuickApplyViewModel(selectedApp: selectedApp))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Tab Bar
            if !viewModel.isLoadingCatalog && viewModel.availableCategories.count > 1 {
                CategoryTabBar(
                    categories: viewModel.availableCategories,
                    selectedCategory: $viewModel.selectedCategory,
                    countProvider: { cat in viewModel.countForCategory(cat) }
                )
            }

            // Main Content Area
            if viewModel.isLoadingCatalog {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.displayedPatches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: SecretKeys.iconEmptyState)
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(SecretKeys.textNoPatchesFound)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Native SwiftUI List ร่วมกับ Multi-Selection State
                List(selection: $viewModel.selectedItems) {
                    Section {
                        ForEach(viewModel.displayedPatches) { item in
                            patchRow(for: item)
                                .tag(item.id)
                        }
                    } header: {
                        HStack {
                            Text("\(SecretKeys.textActivePatchesPrefix)\(viewModel.activeDisplayedPatchesCount)\(SecretKeys.textActivePatchesSuffix)")
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
            
            // Bottom Controls
            if !viewModel.filteredGamePatches.isEmpty && !viewModel.isLoadingCatalog {
                bottomActionButtons
            }
        }
        .navigationTitle(viewModel.selectedApp.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(AppTheme.accent)
        .toolbar {
            // ปุ่ม Select / Done แบบ Native สไลด์ไอคอนวงกลมเลือกอัตโนมัติ
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.fetchCatalog(force: true, showHUD: true)
                    }
                } label: {
                    Image(systemName: SecretKeys.iconRefresh)
                }
                .disabled(viewModel.isLoadingCatalog || viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch)
                .accessibilityLabel(SecretKeys.textAccessibilityRefresh)
            }
        }
        .task {
            await viewModel.fetchCatalog(showHUD: true)
        }
        .onAppear {
            startNetworkMonitoring()
        }
        .onDisappear {
            stopNetworkMonitoring()
        }
    }

    // MARK: - Network Monitoring Logic

    private func startNetworkMonitoring() {
        stopNetworkMonitoring()
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                Task { @MainActor in
                    if self.viewModel.displayedPatches.isEmpty && !self.viewModel.isLoadingCatalog {
                        await self.viewModel.fetchCatalog(showHUD: false)
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "QuickApplyViewNetworkMonitor")
        monitor.start(queue: queue)
        self.networkMonitor = monitor
    }

    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    // MARK: - Patch Row Component

    @ViewBuilder
    private func patchRow(for item: QuickPatchItem) -> some View {
        let isApplied = viewModel.activePatches[item.id] ?? false
        let isServerActive = item.active ?? true
        let isDisabled = viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch
        
        let isRowProcessing = !isApplied && (
            viewModel.processingItemID == item.id 
            || (viewModel.isProcessingBatch && viewModel.selectedItems.contains(item.id))
        )

        let detailText = item.updatedAt.map { "\(SecretKeys.textUpdatePrefix)\($0.toRelativeTimeText)" }

        HStack(spacing: 8) {
            // ฝั่งซ้าย: ใช้ Native UIListContentView จัดการ Spacing & Typography
            NativeListRowContent(
                title: item.title,
                detail: detailText,
                isServerActive: isServerActive
            )

            Spacer(minLength: 4)

            // ฝั่งขวา: สถานะการทำงาน / ปุ่มกด
            ZStack(alignment: .trailing) {
                ActivityIndicator(isAnimating: isRowProcessing, style: .medium)
                    .opacity(isRowProcessing ? 1.0 : 0.0)

                Group {
                    if !isServerActive {
                        if isApplied {
                            Text(SecretKeys.textRestorePatch)
                                .font(.footnote.bold())
                                .foregroundStyle(.red)
                        } else {
                            Text(SecretKeys.textMaintenance)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .foregroundStyle(.red)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.red, lineWidth: 1.0)
                                )
                                .clipShape(Capsule())
                        }
                    } else if isApplied {
                        Text(SecretKeys.textActiveState)
                            .font(.footnote.bold())
                            .foregroundStyle(.green)
                    }
                }
                .opacity(isRowProcessing ? 0.0 : 1.0)
            }
            .transaction { $0.animation = nil }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            
            if !isServerActive {
                if isApplied {
                    viewModel.handleToggleChange(item: item, enable: false)
                }
                return
            }

            viewModel.handleToggleChange(item: item, enable: !isApplied)
        }
        .disabled(isDisabled || (!isServerActive && !isApplied))
    }

    // MARK: - Bottom Action Buttons

    private var bottomActionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.restoreAllPatches()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: SecretKeys.iconRestore)
                            .font(.headline)
                        
                        Text(SecretKeys.textRestoreAll)
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
                .disabled(!viewModel.hasActivePatches || viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch || viewModel.isLoadingCatalog)
                .opacity(viewModel.hasActivePatches ? 1.0 : 0.4)

                Button {
                    viewModel.openGame()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: SecretKeys.iconGameController)
                            .font(.headline)
                        Text(SecretKeys.textOpenGame)
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
                .disabled(viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch || viewModel.isLoadingCatalog)
            }

            if !viewModel.selectedItems.isEmpty {
                Button {
                    viewModel.applyBatchPatches()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: SecretKeys.iconBatchPatch)
                            .font(.headline)
                        Text("\(SecretKeys.textBatchPatchPrefix)\(viewModel.selectedItems.count)\(SecretKeys.textBatchPatchSuffix)")
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
                .disabled(viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch || viewModel.isLoadingCatalog)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.selectedItems.isEmpty)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
}
