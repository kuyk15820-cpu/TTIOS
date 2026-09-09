import SwiftUI

// Struct สำหรับเก็บข้อมูลโฟลเดอร์
struct FolderItem: Identifiable {
    let id = UUID()
    var name: String
    var count: Int = 0
}

struct VoiceMemosHomeView: View {
    @State private var totalRecordingsCount: Int = 0
    @State private var recentlyDeletedCount: Int = 1
    
    @State private var customFolders: [FolderItem] = [
        FolderItem(name: "🫠", count: 0),
        FolderItem(name: "2", count: 0)
    ]
    
    @State private var isShowingNewFolderAlert = false
    @State private var folderName = ""

    var body: some View {
        // 🟢 เอา NavigationStack ออกเพื่อไม่ให้ซ้อนกับ TargetGameView ปุ่ม BottomBar จะกลับมาแสดงผลทันที
        List {
            // Section 1: เสียงบันทึกทั้งหมด & ที่ลบล่าสุด
            Section {
                NavigationLink(destination: AllRecordingsListView(title: "เสียงบันทึกทั้งหมด")) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundColor(.blue)

                        Text("เสียงบันทึกทั้งหมด")
                            .font(.body)

                        Spacer()

                        Text("\(totalRecordingsCount)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: AllRecordingsListView(title: "ที่ลบล่าสุด")) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.blue)

                        Text("ที่ลบล่าสุด")
                            .font(.body)

                        Spacer()

                        Text("\(recentlyDeletedCount)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Section 2: โฟลเดอร์ของฉัน
            if !customFolders.isEmpty {
                Section(header: Text("โฟลเดอร์ของฉัน")) {
                    ForEach(customFolders) { folder in
                        NavigationLink(destination: AllRecordingsListView(title: folder.name)) {
                            HStack {
                                Image(systemName: "folder")
                                    .font(.title3)
                                    .foregroundColor(.blue)

                                Text(folder.name)
                                    .font(.body)

                                Spacer()

                                Text("\(folder.count)")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    // 🟢 ใช้ onDelete และ onMove ตามมาตรฐาน iOS Native (ลบ .swipeActions ออกเพื่อไม่ให้เกิดสีขาว)
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
