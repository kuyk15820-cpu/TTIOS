import SwiftUI

struct LicenseLoginView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    
    // โหลด/บันทึก Key ลง UserDefaults เพื่อซิงค์กับ MainAppFlowView
    @AppStorage("saved_license_key") private var storedKey: String = ""
    
    @State private var licenseKey: String = ""
    @State private var isLoading: Bool = false
    
    // Alert State
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var shouldExitOnAlertDismiss: Bool = false
    @State private var shouldDismissOnSuccess: Bool = false

    var body: some View {
        ZStack {
            // Background Color (Deep Dark Theme)
            Color(red: 0.07, green: 0.07, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Top Navigation / Back Button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .padding(.top, 16)
                .padding(.leading, 20)
                
                // Header Title
                Text("Let's Activate")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                
                // Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("License Key")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    CustomTextField(placeholder: "Eg: XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                }
                .padding(.top, 36)
                .padding(.horizontal, 24)
                
                // Activate Button
                Button(action: {
                    handleActivateKey()
                }) {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Activate")
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
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if shouldExitOnAlertDismiss {
                    exit(0)
                } else if shouldDismissOnSuccess {
                    // อัปเดต AppStorage เมื่อผู้ใช้กด OK เพื่อให้ MainAppFlowView สลับไปหน้า TargetGameView
                    storedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Actions
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
                    presentAlert(title: "System Error", message: result.message ?? "Token package 오류", shouldExit: true)
                    return
                }
                
                if result.status {
                    if let daysLeft = result.daysLeft, daysLeft < 0 {
                        LicenseManager.shared.savedKey = nil
                        storedKey = ""
                        presentAlert(title: "Key Expired", message: "Key นี้หมดอายุแล้ว")
                        return
                    }
                    
                    // บันทึกเฉพาะ LicenseManager ก่อน (ยังไม่อัปเดต storedKey เพื่อรอให้กด OK บน Alert)
                    LicenseManager.shared.savedKey = trimmedKey
                    
                    let expiryText = result.expiry ?? "Unlimited"
                    presentAlert(
                        title: "Success",
                        message: "เปิดใช้งานสำเร็จ!\nหมดอายุวันที่: \(expiryText)",
                        shouldDismiss: true
                    )
                } else {
                    LicenseManager.shared.savedKey = nil
                    storedKey = ""
                    presentAlert(title: "Error", message: result.message ?? "License Key ไม่ถูกต้อง")
                }
            } catch {
                isLoading = false
                presentAlert(title: "Connection Error", message: "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้")
            }
        }
    }
    
    private func handleContactSupport() {
        guard let urlString = LicenseManager.shared.contactLink,
              let url = URL(string: urlString) else {
            presentAlert(title: "Contact", message: "ไม่พบลิงก์ติดต่อแอดมิน")
            return
        }
        UIApplication.shared.open(url)
    }
    
    private func presentAlert(title: String, message: String, shouldExit: Bool = false, shouldDismiss: Bool = false) {
        self.alertTitle = title
        self.alertMessage = message
        self.shouldExitOnAlertDismiss = shouldExit
        self.shouldDismissOnSuccess = shouldDismiss
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
