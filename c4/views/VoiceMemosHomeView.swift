import SwiftUI

// Struct สำหรับเก็บข้อมูลโฟลเดอร์
struct FolderItem: Identifiable {
    let id = UUID()
    var name: String
    var count: Int = 0
}

struct VoiceMemosHomeView: View {
    @Environment(\.editMode) private var editMode
    
    @State private var totalRecordingsCount: Int = 0
    @State private var recentlyDeletedCount: Int = 1
    
    @State private var customFolders: [FolderItem] = [
        FolderItem(name: "ทดสอบ", count: 0),
        FolderItem(name: "1", count: 0)
    ]
    
    @State private var isShowingNewFolderAlert = false
    @State private var folderName = ""

    var body: some View {
        List {
            // Section 1: เสียงบันทึกทั้งหมด & ที่ลบล่าสุด
            Section {
                FolderRowView(title: "เสียงบันทึกทั้งหมด", iconName: "waveform", count: totalRecordingsCount)
                FolderRowView(title: "ที่ลบล่าสุด", iconName: "trash", count: recentlyDeletedCount)
            }
            
            // Section 2: โฟลเดอร์ของฉัน
            if !customFolders.isEmpty {
                Section(header: Text("โฟลเดอร์ของฉัน")) {
                    ForEach(customFolders) { folder in
                        FolderRowView(title: folder.name, iconName: "folder", count: folder.count)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        if let index = customFolders.firstIndex(where: { $0.id == folder.id }) {
                                            customFolders.remove(at: index)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash.fill") // 🟢 แสดงเป็นไอคอนถังขยะสีแดงตอนสไลด์
                                }
                            }
                    }
                    .onDelete(perform: deleteFolder)
                    .onMove(perform: moveFolder)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("เสียงบันทึก")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }

            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Spacer()
                    Button {
                        folderName = ""
                        isShowingNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                    }
                }
            }
        }
        .alert("โฟลเดอร์ใหม่", isPresented: $isShowingNewFolderAlert) {
            TextField("ชื่อ", text: $folderName)
            
            Button(role: .cancel) {
                folderName = ""
            } label: {
                Text("ยกเลิก")
                    .bold()
            }

            Button("บันทึก") {
                let trimmedName = folderName.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty {
                    customFolders.append(FolderItem(name: trimmedName))
                }
                folderName = ""
            }
            .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("ป้อนชื่อสำหรับโฟลเดอร์นี้")
        }
    }

    private func deleteFolder(at offsets: IndexSet) {
        customFolders.remove(atOffsets: offsets)
    }

    private func moveFolder(from source: IndexSet, to destination: Int) {
        customFolders.move(fromOffsets: source, toOffset: destination)
    }
}

// 🟢 Custom Row ที่เปลี่ยน UI ตามโหมดแก้ไขโดยอัตโนมัติ
struct FolderRowView: View {
    @Environment(\.editMode) private var editMode
    let title: String
    let iconName: String
    let count: Int

    var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }

    var body: some View {
        ZStack {
            // NavigationLink แบบซ่อน Arrow มาตรฐาน เพื่อให้คลิกเปิดหน้าได้ปกติ
            NavigationLink(destination: AllRecordingsListView(title: title)) {
                EmptyView()
            }
            .opacity(0)

            HStack {
                // ไอคอนโฟลเดอร์ / Waveform
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.body)

                Spacer()

                if isEditing {
                    // 🟢 ในโหมดแก้ไข: ซ่อนลูกศร > แล้วแสดงปุ่ม 3 จุด (...) แทน
                    Button {
                        // Action เมื่อกด 3 จุด
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                } else {
                    // 🟢 โหมดปกติ: แสดงจำนวน และลูกศร >
                    HStack(spacing: 6) {
                        Text("\(count)")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                    }
                }
            }
        }
    }
}

struct AllRecordingsListView: View {
    let title: String
    
    var body: some View {
        Text("รายการเสียงบันทึก")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VoiceMemosHomeView()
    }
    .preferredColorScheme(.dark)
}
