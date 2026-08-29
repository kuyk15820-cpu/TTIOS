import SwiftUI

struct AppSplashScreenView: View {
    @State private var isAnimating = true

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Spinner (ActivityIndicator)
            ActivityIndicator(isAnimating: isAnimating, style: .medium)
        }
    }
}
