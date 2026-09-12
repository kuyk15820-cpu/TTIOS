import SwiftUI

struct PackageListView: View {
    @StateObject private var viewModel = PackageViewModel()
    
    // Sheet State สำหรับสร้าง และ แก้ไข Package
    @State private var showAddSheet = false
    @State private var editingProject: Project? = nil
    
    // Search Filter
    @State private var searchText = ""

    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return viewModel.projects
        } else {
            return viewModel.projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.projectToken.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Tab Selection Bar
                Picker("Tab Selection", selection: $viewModel.selectedTab) {
                    ForEach(PackageViewModel.PackageTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: viewModel.selectedTab) { _ in
                    Task { await viewModel.fetchProjects() }
                }

                // MARK: - Bulk Action Bar (แสดงเมื่อมีการเลือกไอเทม)
                if !viewModel.selectedIDs.isEmpty {
                    bulkActionBar
                }

                // MARK: - Main Package List
                List {
                    if filteredProjects.isEmpty {
                        //ContentUnavailableView("ไม่พบข้อมูล Package", systemImage: "folder.badge.minus")

// ❌ ของเดิม
ContentUnavailableView("ไม่พบข้อมูล Package", systemImage: "folder.badge.minus")

// 🟢 แก้เป็น
VStack(spacing: 12) {
    Image(systemName: "folder.badge.minus")
        .font(.largeTitle)
        .foregroundColor(.secondary)
    Text("ไม่พบข้อมูล Package")
        .font(.subheadline)
        .foregroundColor(.secondary)
}
.frame(maxWidth: .infinity, minHeight: 200)

                    } else {
                        ForEach(filteredProjects) { project in
                            ProjectRowCell(
                                project: project,
                                isSelected: viewModel.selectedIDs.contains(project.id),
                                currentTab: viewModel.selectedTab,
                                onSelect: { viewModel.toggleSelection(for: project.id) },
                                onEdit: { editingProject = project },
                                onToggleMaint: {
                                    Task { await viewModel.toggleMaintenance(id: project.id, currentStatus: project.isMaintenance) }
                                },
                                onDelete: {
                                    Task { await viewModel.deleteProject(id: project.id) }
                                },
                                onRestore: {
                                    Task { await viewModel.restoreProject(id: project.id) }
                                }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "ค้นหาชื่อ หรือ Token...")
                .refreshable {
                    await viewModel.fetchProjects()
                }
            }
            .navigationTitle("Quản lý Package")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.projects.isEmpty {
                        Button(viewModel.selectedIDs.count == viewModel.projects.count ? "Deselect All" : "Select All") {
                            if viewModel.selectedIDs.count == viewModel.projects.count {
                                viewModel.deselectAll()
                            } else {
                                viewModel.selectAll()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .task {
                await viewModel.fetchProjects()
            }
            .sheet(isPresented: $showAddSheet) {
                AddProjectSheet(viewModel: viewModel)
            }
            .sheet(item: $editingProject) { project in
                EditProjectSheet(project: project, viewModel: viewModel)
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
                    Button("🛠️ ปิดปรับปรุงรายการที่เลือก") {
                        Task { await viewModel.executeBulkAction("maint_selected") }
                    }
                    Button("🗑️ ลบรายการที่เลือก", role: .destructive) {
                        Task { await viewModel.executeBulkAction("delete_selected") }
                    }
                case .maintenance:
                    Button("🟢 เปิดใช้งานรายการที่เลือก") {
                        Task { await viewModel.executeBulkAction("activate_selected") }
                    }
                    Button("🗑️ ลบรายการที่เลือก", role: .destructive) {
                        Task { await viewModel.executeBulkAction("delete_selected") }
                    }
                case .deleted:
                    Button("♻️ กู้คืนรายการที่เลือก") {
                        Task { await viewModel.executeBulkAction("restore_selected") }
                    }
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
}

// MARK: - Single Row Cell
struct ProjectRowCell: View {
    let project: Project
    let isSelected: Bool
    let currentTab: PackageViewModel.PackageTab
    
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggleMaint: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                    Spacer()
                    badgeView
                }

                Text(project.projectToken)
    .font(.system(.caption, design: .monospaced))
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(Color(.systemGray6))
    .cornerRadius(4)

                if let contact = project.contactLink, !contact.isEmpty, let url = URL(string: contact) {
                    Link(destination: url) {
                        Label("Contact Link", systemImage: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if currentTab == .deleted {
                Button(action: onRestore) {
                    Label("กู้คืน", systemImage: "arrow.uturn.backward")
                }
                .tint(.green)
            } else {
                Button(role: .destructive, action: onDelete) {
                    Label("ลบ", systemImage: "trash")
                }

                Button(action: onToggleMaint) {
                    Label(project.isMaintenance ? "เปิดใช้งาน" : "ปิดปรับปรุง", systemImage: "wrench.and.screwdriver")
                }
                .tint(.orange)

                Button(action: onEdit) {
                    Label("แก้ไข", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        if currentTab == .deleted {
            Text("DELETED")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(4)
        } else if project.isMaintenance {
            Text("Bảo trì")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
        } else {
            Text("Active")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(4)
        }
    }
}

// MARK: - Add Project Sheet
struct AddProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PackageViewModel
    
    @State private var name = ""
    @State private var contact = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("รายละเอียด Package")) {
                    TextField("Tên Package (เช่น FreeFire VIP)", text: $name)
                    TextField("Link Contact (https://t.me/...)", text: $contact)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Tạo Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("สร้าง") {
                        Task {
                            let success = await viewModel.createProject(name: name, contact: contact)
                            if success { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Project Sheet
struct EditProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @ObservedObject var viewModel: PackageViewModel

    @State private var name: String = ""
    @State private var contact: String = ""

    init(project: Project, viewModel: PackageViewModel) {
        self.project = project
        self.viewModel = viewModel
        _name = State(initialValue: project.name)
        _contact = State(initialValue: project.contactLink ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("แก้ไขข้อมูล Package")) {
                    TextField("ชื่อ Package", text: $name)
                    TextField("Link Contact", text: $contact)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("✏️ แก้ไข Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        Task {
                            await viewModel.updateProject(id: project.id, name: name, contact: contact)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
