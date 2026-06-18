import SwiftUI
import QuickLook
import ARKit

/// Presents the bundled USDZ in AR Quick Look (`QLPreviewController` +
/// `ARQuickLookPreviewItem`), the system AR placement surface. Wrapped as a
/// SwiftUI `UIViewControllerRepresentable` so the dark-stage viewer can push it
/// from its tungsten "View in AR" button.
struct ARQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            // ARQuickLookPreviewItem enables the in-place AR placement affordance
            // (and lets us disable scaling so the diecast stays display-scale).
            let item = ARQuickLookPreviewItem(fileAt: url)
            item.allowsContentScaling = false
            return item
        }
    }
}
