import SwiftUI
import PhotosUI

struct ImagePickerView: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void

        init(onComplete: @escaping ([UIImage]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                return
            }
            let providers = results.map { $0.itemProvider }
            var images: [UIImage] = []
            let group = DispatchGroup()
            for provider in providers {
                if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let img = object as? UIImage {
                            images.append(img)
                        }
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                self.onComplete(images)
                picker.dismiss(animated: true)
            }
        }
    }
}


