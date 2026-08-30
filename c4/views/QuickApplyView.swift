import SwiftUI
import UIKit

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

// MARK: - QuickApplyView

struct QuickApplyView: View {
    @StateObject private var viewModel: QuickApplyViewModel
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

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
                // ขณะรีเฟรชหรือโหลดข้อมูล -> ซ่อน List ทั้งหมด
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.displayedPatches.isEmpty {
                // โหลดเสร็จแล้วแต่ไม่มีข้อมูล -> แสดง Empty State
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
                // โหลดเสร็จและมีข้อมูล -> แสดง List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Section Header สไตล์ Native List
                        HStack {
                            Text("\(SecretKeys.textActivePatchesPrefix)\(viewModel.activeDisplayedPatchesCount)\(SecretKeys.textActivePatchesSuffix)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // ปุ่มเลือกหลายรายการ
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    viewModel.toggleSelectAll()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: viewModel.isMultiSelectMode ? SecretKeys.iconCheckmarkCircle : SecretKeys.iconCircle)
                                        .font(.caption)
                                    Text(SecretKeys.textMultiSelect)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(viewModel.isMultiSelectMode ? AppTheme.accent.opacity(0.15) : Color.secondary.opacity(0.12))
                                .foregroundColor(viewModel.isMultiSelectMode ? AppTheme.accent : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Color(.systemGroupedBackground))

                        Divider()

                        // Patch List Rows
                        ForEach(viewModel.displayedPatches) { item in
                            patchRow(for: item)
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
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
            // เหลือ Toolbar เฉพาะปุ่ม Refresh เพียงอย่างเดียว
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.fetchCatalog(force: true)
                    }
                } label: {
                    Image(systemName: SecretKeys.iconRefresh)
                }
                .disabled(viewModel.isLoadingCatalog || viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch)
                .accessibilityLabel(SecretKeys.textAccessibilityRefresh)
            }
        }
        .task {
            await viewModel.fetchCatalog()
        }
    }

    // MARK: - Patch Row Component

    @ViewBuilder
    private func patchRow(for item: QuickPatchItem) -> some View {
        let isApplied = viewModel.activePatches[item.id] ?? false
        let isSelected = viewModel.selectedItems.contains(item.id)
        let isServerActive = item.active ?? true
        let isDisabled = viewModel.processingItemID != nil || viewModel.isRestoringAll || viewModel.isProcessingBatch
        
        // 🔴 ปรับเงื่อนไข ActivityIndicator: ไม่แสดงถ้าเป็นการปิด Patch (isApplied == true)
        let isRowProcessing = !isApplied && (
            viewModel.processingItemID == item.id 
            || (viewModel.isProcessingBatch && isSelected)
        )

        Button {
            guard !isDisabled else { return }
            
            if !isServerActive {
                if isApplied {
                    viewModel.handleToggleChange(item: item, enable: false)
                }
                return
            }

            if viewModel.isMultiSelectMode {
                viewModel.toggleSelection(for: item)
            } else {
                viewModel.handleToggleChange(item: item, enable: !isApplied)
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                // อนิเมชั่นสไลด์สำหรับ Checkmark ในโหมดเลือกหลายรายการ
                if viewModel.isMultiSelectMode {
                    Image(systemName: isSelected ? SecretKeys.iconCheckmarkCircle : SecretKeys.iconCircle)
                        .font(.title3)
                        .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.4))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .onTapGesture {
                            guard !isDisabled && isServerActive else { return }
                            viewModel.toggleSelection(for: item)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                    }

                    if let updatedAt = item.updatedAt, !updatedAt.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: SecretKeys.iconClock)
                                .font(.caption2)
                            Text("\(SecretKeys.textUpdatePrefix)\(updatedAt.toRelativeTimeText)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isServerActive ? 1.0 : 0.35)
                .grayscale(isServerActive ? 0.0 : 1.0)

                Spacer(minLength: 4)

                // ปิด Animation เฉพาะในส่วนของ Indicator และสถานะขวามือ
                ZStack(alignment: .trailing) {
                    ActivityIndicator(isAnimating: isRowProcessing, style: .medium)
                        .opacity(isRowProcessing ? 1.0 : 0.0)

                    Group {
                        if !isServerActive {
                            if isApplied {
                                Text(SecretKeys.textRestorePatch)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            } else {
                                Text(SecretKeys.textMaintenance)
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
                        } else if isApplied {
                            Text(SecretKeys.textActiveState)
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .opacity(isRowProcessing ? 0.0 : 1.0)
                }
                .transaction { $0.animation = nil }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.22), value: viewModel.isMultiSelectMode)
        }
        .buttonStyle(NativeListRowButtonStyle(isDisabled: isDisabled || (!isServerActive && !isApplied), isSelected: isSelected))
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
        .background(Color(.systemBackground))
    }
}
