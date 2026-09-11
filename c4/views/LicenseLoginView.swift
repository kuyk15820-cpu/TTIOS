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
                        
                        // 🟢 1. เปลี่ยน Placeholder ให้เป็นตัวอย่างคีย์แบบใหม่
                        CustomTextField(placeholder: "Eg: PKG-dynamic-1234567890", text: $licenseKey)
                        
                        // 🟢 ปุ่ม Paste Key จาก Clipboard
                        Button(action: {
                            handlePasteFromClipboard()
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
                        handleActivateKey()
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
                // ดึง Key เดิมมาจำและกรอกให้อัตโนมัติในช่อง
                if !storedKey.isEmpty {
                    self.licenseKey = storedKey
                } else if let saved = LicenseManager.shared.savedKey {
                    self.licenseKey = saved
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
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    /// 🟢 2. ปรับการ Paste จาก Clipboard รองรับคีย์ยืดหยุ่น (ไม่ตัดขีด - หรือสัญลักษณ์พิเศษออก)
    private func handlePasteFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty else {
            presentAlert(title: "Clipboard", message: "ไม่พบข้อความใน Clipboard")
            return
        }
        
        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // เช็กความยาวคีย์ยืดหยุ่น (ระหว่าง 5 ถึง 50 ตัวอักษร)
        if trimmed.count >= 5 && trimmed.count <= 50 {
            self.licenseKey = trimmed
            handleActivateKey()
        } else {
            presentAlert(title: "Key ไม่ถูกต้อง", message: "ข้อความที่คัดลอกมาไม่ตรงกับรูปแบบ License Key")
        }
    }
    
    private func handleActivateKey() {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            presentAlert(title: "Alert", message: "กรุณากรอก License Key")
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
                    // 🟢 3. ตัดการเช็ก daysLeft < 0 ออกที่ฝั่งแอป (ให้เซิร์ฟเวอร์เป็นคนตัดสิน)
                    // บันทึก Key ไว้ใช้สำหรับครั้งถัดไป
                    LicenseManager.shared.savedKey = trimmedKey
                    storedKey = trimmedKey
                    
                    // นำทางไปหน้า TargetGameView
                    await MainActor.run {
                        self.navigateToGame = true
                    }
                } else {
                    clearSavedKey()
                    
                    // 🟢 4. แสดงข้อความแจ้งเตือนตาม Error Code จากเซิร์ฟเวอร์
                    var errorMessage = result.message ?? "License Key ไม่ถูกต้อง"
                    
                    if result.errCode == "KEY_BANNED" {
                        let reason = result.reason ?? "ละเมิดข้อตกลง"
                        let banUntil = result.banUntil ?? "ถาวร"
                        errorMessage = "คีย์ถูกระงับการใช้งาน\nสาเหตุ: \(reason)\nระยะเวลา: \(banUntil)"
                    }
                    
                    presentAlert(title: "Error", message: errorMessage)
                }
            } catch {
                isLoading = false
                presentAlert(title: "Connection Error", message: "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้")
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
    
    private func presentAlert(title: String, message: String, shouldExit: Bool = false) {
        self.alertTitle = title
        self.alertMessage = message
        self.shouldExitOnAlertDismiss = shouldExit
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
