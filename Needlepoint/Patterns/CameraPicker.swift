import SwiftUI
import UIKit

extension EnvironmentValues {
    /// True when UI tests pass `-ui-testing-fake-camera`.
    @Entry var fakeCamera = false
    /// True when UI tests pass `-ui-testing-no-camera`.
    @Entry var hideCamera = false
}

/// The system camera, for taking a cover photo. Calls `onFinish` with the
/// photo, or with nil when the user cancels.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    /// False on devices without a camera. Some simulators report one.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// A stand-in photo for UI tests, which can't drive the system camera.
    static func fakePhoto() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 1200, height: 900)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.05, green: 0.45, blue: 0.5, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
