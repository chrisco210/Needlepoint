import PDFKit
import UIKit

/// Makes the JPEG covers shown on pattern cards. Covers are capped at
/// `maxDimension` pixels on the long side so cards don't decode full-size
/// photos or PDF pages.
nonisolated enum CoverRenderer {
    static let maxDimension: CGFloat = 1600
    private static let quality: CGFloat = 0.86

    /// Page 1 of a PDF as a JPEG, or nil if the PDF can't be read.
    static func firstPageJPEG(fromPDF data: Data) -> Data? {
        guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let longSide = max(bounds.width, bounds.height)
        guard longSide > 0 else { return nil }
        let scale = maxDimension / longSide
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        return jpeg(from: page.thumbnail(of: size, for: .mediaBox))
    }

    /// A photo as a JPEG no larger than `maxDimension`, or nil if the data
    /// isn't an image.
    static func jpeg(fromImage data: Data) -> Data? {
        UIImage(data: data).flatMap(jpeg(from:))
    }

    static func jpeg(from image: UIImage) -> Data? {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longSide = max(pixels.width, pixels.height)
        guard longSide > 0 else { return nil }
        let factor = min(1, maxDimension / longSide)
        let target = CGSize(width: (pixels.width * factor).rounded(), height: (pixels.height * factor).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).jpegData(withCompressionQuality: quality) { context in
            // JPEG has no transparency, so transparent areas would turn black.
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
