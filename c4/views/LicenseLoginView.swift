import SwiftUI

struct LicenseLoginView: View {
    // MARK: - Properties
    @AppStorage("saved_license_key") private var storedKey: String = ""
    
    @State private var licenseKey: String = ""
    @State private var isLoading: Bool = false
    
    // Control Navigation ไปหน้า TargetGameView
    @State private var navigateToGame: Bool = false
    
    // Alert State
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var shouldExitOnAlertDismiss: Bool = false
    @State private var shouldNavigateOnAlertDismiss: Bool = false

    // 🟢 ตรวจสอบสถานะของ App (Active/Background) สำหรับ Auto-Paste
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Color (Deep Dark Theme)
                Color(red: 0.07, green: 0.07, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header Title
                    Text("Let's Activate")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("License Key")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        CustomTextField(placeholder: "Eg: PKG-1day-1234567890", text: $licenseKey)
                        
                        // 🟢 ปุ่ม Paste Key จาก Clipboard (Manual)
                        Button(action: {
                            handlePasteManual()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste Key from Clipboard")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.95, blue: 0.3)) // Neon Green Accent
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 36)
                    .padding(.horizontal, 24)
                    
                    // Activate / Login Button
                    Button(action: {
                        handleActivateKey(isAuto: false)
                    }) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Login")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    
                    // Contact Link (Support)
                    HStack(spacing: 6) {
                        Text("Don't have a license key?")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            handleContactSupport()
                        }) {
                            Text("Get Key")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.6, green: 0.95, blue: 0.3)) // Neon Green Accent
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    
                    Spacer()
                    
                    // Footer
                    Text("Powered by License System")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
            }
            .onTapGesture {
                // Dismiss Keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onAppear {
                if !storedKey.isEmpty {
                    self.licenseKey = storedKey
                } else if let saved = LicenseManager.shared.savedKey {
                    self.licenseKey = saved
                } else {
                    autoCheckClipboardWithServer()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && licenseKey.isEmpty {
                    autoCheckClipboardWithServer()
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                TargetGameView()
                    .navigationBarBackButtonHidden(true)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if shouldExitOnAlertDismiss {
                        exit(0)
                    } else if shouldNavigateOnAlertDismiss {
                        self.navigateToGame = true
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    /// 🟢 อ่าน Clipboard และส่งยิงเช็กตรงกับ Server อัตโนมัติ (ให้ Server เป็นคนยืนยัน Package)
    private func autoCheckClipboardWithServer() {
        guard let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty else { return }
        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // เช็กความยาวขั้นต่ำเพื่อป้องกันการส่งข้อความสั้นเกินไปยิง API
        guard trimmed.count >= 8 && trimmed.count <= 60 else { return }
        
        self.licenseKey = trimmed
        handleActivateKey(isAuto: true)
    }

    /// กดปุ่ม Paste Key จาก Clipboard ด้วยตัวเอง
    private func handlePasteManual() {
        guard let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty else {
            presentAlert(title: "Clipboard", message: "ไม่พบข้อความใน Clipboard")
            return
        }
        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.licenseKey = trimmed
        handleActivateKey(isAuto: false)
    }
    
    /// 🟢 ฟังก์ชันส่ง Key ให้ Server (PHP) ตรวจสอบ Package และสถานะคีย์
    private func handleActivateKey(isAuto: Bool) {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            if !isAuto { presentAlert(title: "Alert", message: "กรุณากรอก License Key") }
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let result = try await LicenseManager.shared.verifyKey(trimmedKey)
                isLoading = false
                
                if result.forceExit == true {
                    presentAlert(title: "System Error", message: result.message ?? "Token package มีปัญหา", shouldExit: true)
                    return
                }
                
                if result.status {
                    // 🟢 Key ถูกต้อง และตรงกับ Package นี้แน่นอน
                    LicenseManager.shared.savedKey = trimmedKey
                    storedKey = trimmedKey
                    
                    let expiryText = result.expiry ?? "Unlimited"
                    let daysText: String
                    
                    if let days = result.daysLeft {
                        if days >= 99999 || expiryText.lowercased() == "lifetime" {
                            daysText = "ตลอดชีพ (Lifetime)"
                        } else {
                            daysText = "\(days) วัน"
                        }
                    } else {
                        daysText = "ไม่ระบุ"
                    }
                    
                    let successMessage = "เปิดใช้งานสำเร็จ!\n\nวันหมดอายุ: \(expiryText)\nคงเหลือ: \(daysText)"
                    
                    await MainActor.run {
                        presentAlert(
                            title: "Activation Success",
                            message: successMessage,
                            shouldNavigate: true
                        )
                    }
                } else {
                    // 🔴 ถ้าทำ Auto-Paste แล้ว Server แจ้งว่า Key ไม่ใช่ของ Package นี้ ให้ลบข้อความทิ้งแล้วนิ่งไว้ (ไม่ขึ้น Alert กวนใจ)
                    if isAuto {
                        self.licenseKey = ""
                    } else {
                        clearSavedKey()
                        
                        var errorMessage = result.message ?? "License Key ไม่ถูกต้อง"
                        
                        if result.errCode == "KEY_BANNED" {
                            let reason = result.reason ?? "ละเมิดข้อตกลง"
                            let banUntil = result.banUntil ?? "ถาวร"
                            errorMessage = "คีย์ถูกระงับการใช้งาน\nสาเหตุ: \(reason)\nระยะเวลา: \(banUntil)"
                        }
                        
                        presentAlert(title: "Error", message: errorMessage)
                    }
                }
            } catch {
                isLoading = false
                if !isAuto {
                    presentAlert(title: "Connection Error", message: "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้")
                } else {
                    self.licenseKey = ""
                }
            }
        }
    }
    
    private func clearSavedKey() {
        LicenseManager.shared.savedKey = nil
        storedKey = ""
    }
    
    private func handleContactSupport() {
        guard let urlString = LicenseManager.shared.contactLink,
              let url = URL(string: urlString) else {
            presentAlert(title: "Contact", message: "ไม่พบลิงก์ติดต่อแอดมิน")
            return
        }
        UIApplication.shared.open(url)
    }
    
    private func presentAlert(title: String, message: String, shouldExit: Bool = false, shouldNavigate: Bool = false) {
        self.alertTitle = title
        self.alertMessage = message
        self.shouldExitOnAlertDismiss = shouldExit
        self.shouldNavigateOnAlertDismiss = shouldNavigate
        self.showAlert = true
    }
}

// MARK: - Custom UI Helper for Rounded TextField
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    .padding(.leading, 16)
            }
            
            TextField("", text: $text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .frame(height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    LicenseLoginView()
}
