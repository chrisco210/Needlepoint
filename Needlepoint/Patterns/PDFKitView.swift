import PDFKit
import SwiftUI

/// A scrollable PDF.
struct PDFKitView: UIViewRepresentable {
    let data: Data
    /// Set on the PDFView itself, because an identifier on the SwiftUI
    /// wrapper doesn't reliably reach the UIKit view in UI tests.
    let accessibilityID: String

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.accessibilityIdentifier = accessibilityID
        view.document = PDFDocument(data: data)
        context.coordinator.shownData = data
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        // Rebuilding the document resets the scroll position, so only do it
        // when the file was replaced.
        guard context.coordinator.shownData != data else { return }
        view.document = PDFDocument(data: data)
        context.coordinator.shownData = data
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shownData: Data?
    }
}
