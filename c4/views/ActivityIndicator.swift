import SwiftUI
import UIKit

// MARK: - UIActivityIndicatorView Wrapper
struct ActivityIndicator: UIViewRepresentable {
    var isAnimating: Bool = true
    var style: UIActivityIndicatorView.Style = .medium

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: style)
        indicator.hidesWhenStopped = true
        indicator.color = .white // 🟢 ปรับสี Spinner เป็นสีขาว
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}
