import SwiftUI

struct AppSplashScreenView: View {
    @State private var isAnimating = true

    var body: some View {
        ZStack {
            // Background ดำสนิท
            Color.black
                .ignoresSafeArea()

            // Spinner (ActivityIndicator) ตรงกลาง
            ActivityIndicator(isAnimating: isAnimating, style: .medium)
                .scaleEffect(1.2)
        }
    }
}
